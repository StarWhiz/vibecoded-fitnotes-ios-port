#!/usr/bin/env ruby
require 'xcodeproj'

project = Xcodeproj::Project.open(File.join(__dir__, 'FitNotes.xcodeproj'))
main_target = project.targets.find { |t| t.name == 'FitNotes' }

services_group = project.main_group.find_subpath('Services', false)
raise "Services group not found" unless services_group

existing = services_group.files.find { |f| f.path == 'AppGroup.swift' }
if existing
  puts "Already in project"
else
  file_ref = services_group.new_reference('AppGroup.swift')
  file_ref.set_source_tree('<group>')
  main_target.source_build_phase.add_file_reference(file_ref)
  puts "ADDED: Services/AppGroup.swift"
end

project.save
