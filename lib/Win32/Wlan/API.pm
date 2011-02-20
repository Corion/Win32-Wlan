package Win32::Wlan::API;
use strict;
use Carp qw(croak);

use Win32::API; # sorry, 64bit users
use Encode qw(decode);
use List::MoreUtils qw(zip);

use Exporter 'import';

use vars qw($VERSION $wlan_available %API @signatures @EXPORT_OK);
$VERSION = '0.01';

sub Zero() { "\0\0\0\0" };
# just in case we ever get a 64bit Win32::API
# Zero will have to return 8 bytes of zeroes

BEGIN {
    @signatures = (
        ['WlanOpenHandle' => 'IIPP' => 'I'],
        ['WlanCloseHandle' => 'II' => 'I'],
        ['WlanFreeMemory' => 'I' => 'I'],
        ['WlanEnumInterfaces' => 'IIP' => 'I'],
        ['WlanQueryInterface' => 'IPIIPPI' => 'I'],
        ['WlanGetAvailableNetworkList' => 'IPIIP' => 'I'],
    );

    @EXPORT_OK = (qw<$wlan_available WlanQueryCurrentConnection>, map { $_->[0] } @signatures);
};

use constant {
  not_ready               => 0,
  connected               => 1,
  ad_hoc_network_formed   => 2,
  disconnecting           => 3,
  disconnected            => 4,
  associating             => 5,
  discovering             => 6,
  authenticating          => 7 
};

if (! load_functions()) {
    # Wlan functions are not available
    $wlan_available = 0;
} else {
    $wlan_available = 1;
};

sub WlanOpenHandle {
    croak "Wlan functions are not available" unless $wlan_available;
    my $version = Zero;
    my $handle = Zero;
    $API{ WlanOpenHandle }->Call(2,0,$version,$handle) == 0
        or croak $^E;
    my $h = unpack "V", $handle;
    $h
};

sub WlanCloseHandle {
    croak "Wlan functions are not available" unless $wlan_available;
    my ($handle) = @_;
    $API{ WlanCloseHandle }->Call($handle,0) == 0
        or croak $^E;
};

sub WlanFreeMemory {
    croak "Wlan functions are not available" unless $wlan_available;
    my ($block) = @_;
    $API{ WlanFreeMemory }->Call($block);
};

sub _unpack_counted_array {
    my ($pointer,$template,$size) = @_;
    my $info = unpack 'P8', $pointer;
    my ($count,$curr) = unpack 'VV', $info;
    my $data = unpack "P" . (8+$count*$size), $pointer;
    my @items = unpack "x8 ($template)$count", $data;
    my $elements_per_item = @items / $count;
    my @res;
    while (@items) {
        push @res, [splice @items, 0, $elements_per_item ]
    };
    @res
};

sub WlanEnumInterfaces {
    croak "Wlan functions are not available" unless $wlan_available;
    my ($handle) = @_;
    my $interfaces = Zero;
    $API{ WlanEnumInterfaces }->Call($handle,0,$interfaces) == 0
        or croak $^E;
    my @items = _unpack_counted_array($interfaces,'a16 a512 V',16+512+4);
    for (@items) {
        # First element is the GUUID of the interface
        # Name is in 16bit UTF
        $_->[1] = decode('UTF-16LE' => $_->[1]);
        $_->[1] =~ s/\0+$//;
        # The third element is the status of the interface
    };
    
    $interfaces = unpack 'V', $interfaces;
    WlanFreeMemory($interfaces);
    @items
};

sub WlanQueryInterface {
    croak "Wlan functions are not available" unless $wlan_available;
    my ($handle,$interface,$op) = @_;
    my $size = Zero;
    my $data = Zero;
    $API{ WlanQueryInterface }->Call($handle, $interface, $op, 0, $size, $data, 0) == 0
        or croak $^E;
    use Data::Dumper;
    $size = unpack 'V', $size;
    my $payload = unpack "P$size", $data;
    
    $data = unpack 'V', $data;
    WlanFreeMemory($data);
    $payload
};

sub WlanQueryCurrentConnection {
    my ($handle,$interface) = @_;
    my $info = WlanQueryInterface($handle,$interface,7);
    
    my %res;
    # Unpack WLAN_CONNECTION_ATTRIBUTES
    @res{qw(  state mode profile_name association security )} = 
        unpack 'V    V    a512         V             V', $info;
    $res{ profile_name } = decode('UTF-16LE', $res{ profile_name });
    $res{ profile_name } =~ s/\0+$//;
    
    %res
}

sub WlanGetAvailableNetworkList {
    my ($handle,$interface,$flags) = @_;
    $flags ||= 0;
    my $list = Zero;
    $API{ WlanGetAvailableNetworkList }->Call($handle,$interface,$flags,0,$list) == 0
        or croak $^E;
                                                # name ssid_len ssid bss  bssids connectable
    my @items = _unpack_counted_array($list, join( '', 
        'a512', # name
        'V',    # ssid_len
        'a32',  # ssid
        'V',    # bss
        'V',    # bssids
        'V',    # connectable
        'V',    # notConnectableReason,
        'V',    # PhysTypes
        'V8',   # PhysType elements
        'V',    # More PhysTypes
        'V',    # wlanSignalQuality from 0=-100dbm to 100=-50dbm, linear
        'V',    # bSecurityEnabled;
        'V',    # dot11DefaultAuthAlgorithm;
        'V',    # dot11DefaultCipherAlgorithm;
        'V',    # dwFlags
        'V',    # dwReserved;
    ), 512+4+32+20*4);
    for (@items) {
        my %info;
        @info{qw( name ssid_len ssid bss bssids connectable notConnectableReason
                  phystype_count )} = splice @$_, 0, 8;
        $info{ phystypes }= [splice @$_, 0, 8];
        @info{qw( has_more_phystypes
                  signal_quality
                  security_enabled
                  dot11_default_auth_algorithm
                  dot11_default_cipher_algorithm
                  flags
                  reserved
        )} = @$_;
        
        # Decode the elements
        $info{ ssid } = substr( $info{ ssid }, 0, $info{ ssid_len });
        $info{ name } = decode('UTF-16LE', $info{ name });
        $info{ name } =~ s/\0+$//;
        splice @{$info{ phystypes }}, $info{ phystype_count };

        $_ = \%info;
    };
    
    $list = unpack 'V', $list;
    WlanFreeMemory($list);
    @items
}

sub load_functions {
    for my $sig (@signatures) {
        $API{ $sig->[0] } = eval {
            Win32::API->new( 'wlanapi.dll', @$sig );
        };
        if (! $API{ $sig->[0] }) {
            return
        };
    };
    1
};

1;

__END__

=head1 NAME

Win32::Wlan::API - Access to the Win32 WLAN API

=head1 SYNOPSIS

    use Win32::Wlan::API qw(WlanOpenHandle WlanEnumInterfaces WlanQueryCurrentConnection);
    if ($Win32::Wlan::available) {
        my $handle = WlanOpenHandle();
        my @interfaces = WlanEnumInterfaces($handle);
        my $ih = $interfaces[0]->[0];
        my $info = WlanQueryCurrentConnection($handle,$ih);
        print "Connected to $info{ profile_name }\n";        

    } else {
        print "No Wlan detected (or switched off)\n";
    };

=head1 SEE ALSO

Windows Native Wifi Reference

L<http://msdn.microsoft.com/en-us/library/ms706274%28v=VS.85%29.aspx>

=head1 REPOSITORY

The public repository of this module is 
L<http://github.com/Corion/Win32-Wlan>.

=head1 SUPPORT

The public support forum of this module is
L<http://perlmonks.org/>.

=head1 BUG TRACKER

Please report bugs in this module via the RT CPAN bug queue at
L<https://rt.cpan.org/Public/Dist/Display.html?Name=Win32-Wlan>
or via mail to L<win32-wlan-Bugs@rt.cpan.org>.

=head1 AUTHOR

Max Maischein C<corion@cpan.org>

=head1 COPYRIGHT (c)

Copyright 2011-2011 by Max Maischein C<corion@cpan.org>.

=head1 LICENSE

This module is released under the same terms as Perl itself.

=cut
