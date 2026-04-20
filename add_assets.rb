#!/usr/bin/env ruby
require 'xcodeproj'

PROJECT_PATH = File.join(__dir__, 'FitNotes.xcodeproj')
ASSETS_PATH  = 'Assets.xcassets'

project = Xcodeproj::Project.open(PROJECT_PATH)
main_target = project.targets.find { |t| t.name == 'FitNotes' }
raise "Could not find FitNotes target" unless main_target

# Skip if already present
already = project.main_group.files.find { |f| f.path == ASSETS_PATH }
if already
  puts "Assets.xcassets already in project — nothing to do."
  exit 0
end

# Add as a group reference (folder-type)
file_ref = project.main_group.new_reference(ASSETS_PATH)
file_ref.last_known_file_type = 'folder.assetcatalog'
file_ref.set_source_tree('<group>')

# Add to the Resources build phase
resources_phase = main_target.resources_build_phase
resources_phase.add_file_reference(file_ref)

project.save
puts "Added Assets.xcassets to FitNotes target resources."
