#perl -w
use strict;
use Test::More tests;
if ($^O !~ /Win32/i) {
    plan skip_all => "Win32::Wlan only works on Win32";
} else {
    plan tests => 1;
};


use Win32::Wlan::API qw(WlanOpenHandle WlanEnumInterfaces WlanQueryCurrentConnection);
if ($Win32::Wlan::API::available) {
    my $handle = WlanOpenHandle();
    my @interfaces = WlanEnumInterfaces($handle);
    my $ih = $interfaces[0]->[0];
    my %info = WlanQueryCurrentConnection($handle,$ih);
    diag "Connected to $info{ profile_name }\n";        

} else {
    diag "No Wlan detected (or switched off)\n";
};

ok 1, "Synopsis does not crash";
