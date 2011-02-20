#perl -w
use strict;
use Test::More tests => 5;

use Win32::Wlan::API;

my $handle;
ok eval {
    $handle = Win32::Wlan::API::WlanOpenHandle();
    1
};
is $@, '', "No error";
ok $handle, "We got a handle";

my @interfaces = Win32::Wlan::API::WlanEnumInterfaces($handle);

ok eval {
    Win32::Wlan::API::WlanCloseHandle($handle);
    1
}, "Released the handle";
is $@, '', "No error";
