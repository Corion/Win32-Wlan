#perl -w
use strict;
use Test::More tests => 5;

use Win32::Wlan;
use Data::Dumper;

my $handle;
ok eval {
    $handle = Win32::Wlan::WlanOpenHandle();
    1
};
is $@, '', "No error";
ok $handle, "We got a handle";

my @interfaces = Win32::Wlan::WlanEnumInterfaces($handle);
diag Dumper \@interfaces;

ok eval {
    Win32::Wlan::WlanCloseHandle($handle);
    1
}, "Released the handle";
is $@, '', "No error";
