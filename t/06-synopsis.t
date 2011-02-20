#perl -w
use strict;
use Test::More;
BEGIN {
    if ($^O !~ /Win32/i) {
        plan skip_all => "Win32::Wlan only works on Win32";
    } else {
        plan 'tests' => 4;
    };
}

use Win32::Wlan;

my $wlan = Win32::Wlan->new( available => 0 );
isa_ok $wlan, 'Win32::Wlan';
ok ! $wlan->available, "If we say it's unavailable, it is";

my $wlan = Win32::Wlan->new();
if ($wlan->available) {
    diag "We have a wlan connection";
    ok $wlan->interface->{name}, "We have a name for the interface";
    if ($wlan->connected) {
        my $connection = $wlan->connection;
        ok $connection->{profile_name}, "We have a profile name";
    } else {
        SKIP: {
            skip 1, "... but we have no connection";
        };
    };
} else {
    SKIP: {
        skip 2, "Wlan is unavailable";
    }
};
