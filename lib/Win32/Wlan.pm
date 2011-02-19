package Win32::Wlan;
use strict;
use Carp qw(croak);

use Win32::API; # sorry, 64bit users
use Encode qw(decode);
use List::MoreUtils qw(zip);

use vars qw($VERSION $available %API @signatures);
$VERSION = '0.01';

sub Zero() { "\0\0\0\0" };
# just in case we ever get a 64bit Win32::API
# Zero will have to return 8 bytes of zeroes

@signatures = (
    ['WlanOpenHandle' => 'IIPP' => 'I'],
    ['WlanCloseHandle' => 'II' => 'I'],
    ['WlanFreeMemory' => 'I' => 'I'],
    ['WlanEnumInterfaces' => 'IIP' => 'I'],
    ['WlanQueryInterface' => 'IPIIPPI' => 'I'],
    ['WlanGetAvailableNetworkList' => 'IPIIP' => 'I'],
);

if (! load_functions()) {
    # Wlan functions are not available
    $available = 0;
} else {
    $available = 1;
};

sub WlanOpenHandle {
    croak "Wlan functions are not available" unless $available;
    my $version = Zero;
    my $handle = Zero;
    $API{ WlanOpenHandle }->Call(2,0,$version,$handle) == 0
        or croak $^E;
    unpack "V", $handle
};

sub WlanCloseHandle {
    croak "Wlan functions are not available" unless $available;
    my ($handle) = @_;
    $API{ WlanCloseHandle }->Call($handle,0) == 0
        or croak $^E;
    $handle
};

sub WlanFreeMemory {
    croak "Wlan functions are not available" unless $available;
    my ($block) = @_;
    $API{ WlanFreeMemory }->Call($block);
};

sub _unpack_count_array {
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
    croak "Wlan functions are not available" unless $available;
    my ($handle) = @_;
    my $interfaces = Zero;
    $API{ WlanEnumInterfaces }->Call($handle,0,$interfaces) == 0
        or croak $^E;
    my @items = _unpack_count_array($interfaces,'a16 a512 V',16+512+4);
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
    croak "Wlan functions are not available" unless $available;
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
    
    \%res
}

sub WlanGetAvailableNetworkList {
    my ($handle,$interface,$flags) = @_;
    $flags ||= 0;
    my $list = Zero;
    $API{ WlanGetAvailableNetworkList }->Call($handle,$interface,$flags,0,$list) == 0
        or croak $^E;
                                                # name ssid_len ssid bss  bssids connectable
    my @items = _unpack_count_array($list, join '', 
                                    'a512', # name
                                    'V',    # ssid_len
                                    'a32',  # ssid
                                    'V',    # bss
                                    'V',    # bssids
                                    'V',    # connectable
                                    'V',    # notConnectableReason,
                                    'V',    # PhysTypes
                                    'V32',  # PhysType elements
                                    'V',    # More PhysTypes
                                    
                                    
                                    , 512+4+32+4+4+4);
    for (@items) {
        # First element is the GUUID of the interface
        # Name is in 16bit UTF
        $_->[1] = decode('UTF-16LE' => $_->[1]);
        $_->[1] =~ s/\0+$//;
        # The third element is the status of the interface
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

Win32::Wlan - Access to the Win32 WLAN API

=head1 SEE ALSO

Windows Native Wifi Reference

L<http://msdn.microsoft.com/en-us/library/ms706274%28v=VS.85%29.aspx>

=cut
