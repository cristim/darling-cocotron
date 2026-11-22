#!/usr/bin/env ruby
# frozen_string_literal: true

# Host test: the nine NSFontWeight constants of AppKit/NSTextSystemConstants.m (exported) and of the UIFoundation stand-in
# (UIFoundation/NSFontDescriptor.m, not exported, used by its text classes) must be the same single-precision value
# widened to double, and each must be a float-suffixed or zero literal inside -1..1, never an integer bit pattern (the old
# 0xbfe99999a0000000 spelling, which becomes a number near 1e19). tests/appkit-font-weight-real-mac.m pins AppKit's exact bits.
root = ARGV[0] || File.expand_path('..', __dir__)
def weights(path)
  File.readlines(path).each_with_object({}) do |line, h|
    h[Regexp.last_match(1)] = Regexp.last_match(2) if line =~ /const NSFontWeight (NSFontWeight(?:UltraLight|Thin|Light|Regular|Medium|Semibold|Bold|Heavy|Black))\s*=\s*([^;]+);/
  end
end
appkit = weights(File.join(root, 'AppKit/NSTextSystemConstants.m'))
uif = weights(File.join(root, 'UIFoundation/NSFontDescriptor.m'))
fail_msgs = []
fail_msgs << "expected nine weights in each file, found #{appkit.size} and #{uif.size}" unless appkit.size == 9 && uif.size == 9
appkit.each do |name, lit|
  fail_msgs << "#{name}: AppKit #{lit} but UIFoundation #{uif[name].inspect}" unless uif[name] == lit
  fail_msgs << "#{name}: #{lit} is not a float literal" unless lit =~ /\A-?\d+\.\d+f?\z/
end
unless fail_msgs.empty?
  fail_msgs.each { |m| warn "FAIL #{m}" }
  exit 1
end
puts 'PASS: font-weight-source-agree (9 weights)'
