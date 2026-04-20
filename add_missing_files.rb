#!/usr/bin/env ruby
require 'xcodeproj'

PROJECT_PATH = File.join(__dir__, 'FitNotes.xcodeproj')
project = Xcodeproj::Project.open(PROJECT_PATH)

main_target = project.targets.find { |t| t.name == 'FitNotes' }
raise "Could not find FitNotes target" unless main_target

# Files to add to main app target with their source directories
main_app_files = [
  { path: 'LiveActivity/RestTimerAttributes.swift',    group_name: 'LiveActivity' },
  { path: 'Intents/GymFocusFilter.swift',              group_name: 'Intents' },
  { path: 'Intents/FitNotesShortcuts.swift',           group_name: 'Intents' },
  { path: 'Intents/StartWorkoutIntent.swift',          group_name: 'Intents' },
  { path: 'Intents/LogSetIntent.swift',                group_name: 'Intents' },
  { path: 'Intents/StartRestTimerIntent.swift',        group_name: 'Intents' },
  { path: 'Intents/ExerciseStatusIntent.swift',        group_name: 'Intents' },
  { path: 'Intents/OneRMIntent.swift',                 group_name: 'Intents' },
]

main_app_files.each do |file_info|
  full_path = File.join(__dir__, file_info[:path])
  unless File.exist?(full_path)
    puts "  SKIP (not found): #{file_info[:path]}"
    next
  end

  group_name = file_info[:group_name]
  group = project.main_group.find_subpath(group_name, true)
  group.set_source_tree('<group>')
  group.set_path(group_name)

  # Skip if already added
  existing = group.files.find { |f| f.path == File.basename(file_info[:path]) }
  if existing
    puts "  SKIP (already in project): #{file_info[:path]}"
    next
  end

  file_ref = group.new_reference(File.basename(file_info[:path]))
  file_ref.set_source_tree('<group>')

  build_file = main_target.source_build_phase.add_file_reference(file_ref)
  puts "  ADDED: #{file_info[:path]}"
end

project.save
puts "\nProject saved."
