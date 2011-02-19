package Win32::Wlan;
use strict;
use Carp qw(croak);

use Win32::API; # sorry, 64bit users
use Encode qw(decode);

#DWORD WINAPI WlanOpenHandle(
#  __in        DWORD dwClientVersion,
#  __reserved  PVOID pReserved,
#  __out       PDWORD pdwNegotiatedVersion,
#  __out       PHANDLE phClientHandle
#);

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

sub WlanEnumInterfaces {
    croak "Wlan functions are not available" unless $available;
    my ($handle) = @_;
    my $interfaces = Zero;
    $API{ WlanEnumInterfaces }->Call($handle,0,$interfaces) == 0
        or croak $^E;
    my $info = unpack 'P8', $interfaces;
    use Data::Dumper;
    my ($count,$curr) = unpack 'VV', $info;
    #warn "$count interfaces";
    my @res;
    if ($count) {
        my $data = unpack "P" . (8+$count*(16+512+4)), $interfaces;
        my @items = unpack "x8 (a16 a512 V)$count", $data;
        while (@items) {
            # First element is the GUUID of the interface
            # Name is in 16bit UTF
            $items[1] = decode('UTF-16LE' => $items[1]);
            $items[1] =~ s/\0+$//;
            # The third element is the status of the interface
            push @res, [splice @items, 0, 3];
        };
    };
    
    $interfaces = unpack 'V', $interfaces;
    WlanFreeMemory($interfaces);
    @res
};

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
