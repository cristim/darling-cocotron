#!/usr/bin/env ruby
# frozen_string_literal: true

# Host test: a name that both AppKit/NSTextSystemConstants.m and the UIFoundation stand-in (UIFoundation/NSAttributedStringKeys.m)
# define must hold the same string in both, because the stand-in's own copies are not exported
# (UIFoundation/unexported-symbols.txt) and its text classes look attributes up under them, while apps and AppKit's text code
# use AppKit's. tests/appkit-attribute-name-constants.m pins AppKit's strings; this pins the pairs. Also fails when no name is
# shared (the check would pass vacuously).
root = ARGV[0] || File.expand_path('..', __dir__)
def defs(path)
  File.readlines(path).each_with_object({}) do |line, h|
    h[Regexp.last_match(1)] = Regexp.last_match(2) if line =~ /\b(NS\w+AttributeName)\s*=\s*@"([^"]*)"/
  end
end
appkit = defs(File.join(root, 'AppKit/NSTextSystemConstants.m'))
uif = defs(File.join(root, 'UIFoundation/NSAttributedStringKeys.m'))
shared = appkit.keys & uif.keys
abort 'FAIL: no attribute name is defined in both files' if shared.empty?
bad = shared.reject { |n| appkit[n] == uif[n] }
unless bad.empty?
  bad.each { |n| warn "FAIL #{n}: AppKit #{appkit[n].inspect}, UIFoundation #{uif[n].inspect}" }
  exit 1
end
puts "PASS: attribute-name-source-agree (#{shared.size} shared names)"
