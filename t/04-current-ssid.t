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

for my $i (@interfaces) {
    diag "Querying interface $i->[1]";
    my $ih = $i->[0];
    my %info = Win32::Wlan::WlanQueryCurrentConnection($handle,$ih);
    
    diag Dumper \%info;
};

ok eval {
    Win32::Wlan::WlanCloseHandle($handle);
    1
}, "Released the handle";
is $@, '', "No error";
