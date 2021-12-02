# Example class how to maintain a cache of IRB records to minimize the amount of network activity

# Generates a list of ranges used to slice an array into chunks no larger
# than the given chunk size.
def ranges(array_size, max_chunk_size = 1000)
  start = 0
  stop = max_chunk_size
  data = []
  while start < array_size
    data << (start..stop - 1)
    start = stop
    stop = stop + max_chunk_size
  end
  data
end

# Singleton that caches the results of a sparc_irb request for active irbs.
class IrbStatusCache
  include Singleton
  attr_reader :irb_records, :submission_types

  def initialize
    self.clear
  end

  def clear
    # hash associating an irb with its corresponding record from the sparc_irb service.
    @irb_records = {}
    @submission_types = []
  end

  # Populate the cache by querying the irb_service API for data.
  #
  # @param query_size: Integer - number of records to query for at a time
  # @param api_method: String - API endpoint to query; default is lookup_irbs. Other options are:
  #    'inactive_irbs' and 'active_irbs'
  # @param irbs List[String] - list of irbs to query
  def populate(query_size: 500, api_method: 'lookup_irbs', irbs: nil)
    self.clear
    @submission_types = PermissibleValue.get_key_list('submission_type')

    all_irbs = irbs || IrbRecord.where.not(:pro_number => [nil, '']).pluck(:pro_number).uniq
    url = Setting.get_value("research_master_api") + "#{api_method}.json"

    # Chunk queries to the rdwservice to no more than 1000 items.
    ranges(all_irbs.size, query_size).each do |range|
      # Query the API to retrieve the attributes associated with the given IRBs.
      resp = HTTParty.post(url,
                           :body => all_irbs[range].to_json,
                           :headers => {
                             'Content-Type' => 'application/json',
                             'Authorization' => "Token token=\"#{Setting.get_value("rmid_api_token")}\""
                           })
      self.add_all(resp.parsed_response)
    end
    self
  end

  # Clears any existing cached values and creates a new cache from the provided
  # records, which are the result of a query to the sparc_irb service
  # (an array of hashes).
  def records=(recs)
    self.clear
    add_all(recs)
  end

  def add_all(recs)
    recs.each do |rec|
      @irb_records[rec['eirb_pro_number']] = rec
    end
  end

  def has_data?(irb)
    @irb_records.has_key?(irb)
  end

  def status(irb)
    value(irb, 'status')
  end

  # IRB-related attributes used to update a IrbRecord instance.
  def irb_attrs(irb)
    record = @irb_records[irb]
    attrs = {}
    if record
      attrs[:initial_irb_approval_date] = to_date(record['date_initially_approved'])
      attrs[:irb_approval_date] = to_date(record['date_approved'])
      attrs[:irb_expiration_date] = to_date(record['date_expiration'])
      submission_type = record['submission_type']
      attrs[:submission_type] = submission_type if @submission_types.include?(submission_type)
    end
    attrs
  end

  def value(irb, field_name)
    @irb_records[irb] ? @irb_records[irb][field_name] : nil
  end

  # Convert the given date string to a Date; returns nil if given value is nil.
  def to_date(val, dt_format = "%m/%d/%Y")
    val.nil? ? nil : Date.strptime(val, dt_format)
  end
end
