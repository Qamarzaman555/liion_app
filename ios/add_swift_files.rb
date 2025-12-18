#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.first

# Get the Runner group
runner_group = project.main_group['Runner']

# Swift files to add
swift_files = [
  'BackgroundService.swift',
  'BackendLoggingService.swift',
  'BLEService.swift',
  'BackgroundServiceChannel.swift'
]

swift_files.each do |filename|
  file_path = "Runner/#{filename}"
  
  # Check if file already exists in project
  existing_file = runner_group.files.find { |f| f.path == filename }
  
  if existing_file
    puts "✓ #{filename} already in project"
    next
  end
  
  # Add file reference to the Runner group
  file_ref = runner_group.new_reference(filename)
  file_ref.last_known_file_type = 'sourcecode.swift'
  file_ref.source_tree = '<group>'
  
  # Add file to build phase (compile sources)
  target.source_build_phase.add_file_reference(file_ref)
  
  puts "✓ Added #{filename} to project"
end

# Save the project
project.save

puts "\n✅ All Swift files added successfully!"
puts "Now run: cd /Users/qamarzaman/StudioProjects/liion_app && flutter clean && flutter run"

