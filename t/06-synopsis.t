#perl -w
use strict;
use Test::More tests => 1;

use Win32::Wlan qw(WlanOpenHandle WlanEnumInterfaces WlanQueryCurrentConnection);
if ($Win32::Wlan::available) {
    my $handle = WlanOpenHandle();
    my @interfaces = WlanEnumInterfaces($handle);
    my $ih = $interfaces[0]->[0];
    my %info = WlanQueryCurrentConnection($handle,$ih);
    diag "Connected to $info{ profile_name }\n";        

} else {
    diag "No Wlan detected (or switched off)\n";
};

ok 1, "Synopsis does not crash";
