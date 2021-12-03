# Rake tasks for managing IRB information
# Usage: rails org:irbs:update

# Note: MUSC uses a similar rake task called 'update_protocol_with_validated_rm'.

require 'progress_bar'

namespace :org do
  namespace :irbs do
    desc "Update IRB info with the latest values from the sparc_irb service."
    task :update => :environment do
      puts "Initializing task..."
      cache = IrbStatusCache.instance
      cache.populate

      # Only update records with a specific institution or unspecified irb_of_record.
      # These are found in the institutions table
      institutions = [nil, '', 'Our Org']
      irb_records = IrbRecord.where(:irb_of_record => institutions)
                                             .where.not(:pro_number => [nil, ''])
                                             .select { |irb| cache.has_data?(irb.pro_number) }

      progress_bar = ProgressBar.new(irb_records.size)

      irb_records.each do |irb|
        irb.update(cache.irb_attrs(irb.pro_number))
        progress_bar.increment!
      end
      cache.clear
    end
  end
end
