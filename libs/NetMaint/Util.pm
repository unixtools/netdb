# Begin-Doc
# Name: NetMaint::Util
# Type: module
# Description: Misc. standalone utility routines
# End-Doc

package NetMaint::Util;
require 5.000;
require Exporter;
use strict;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

use UMR::UsageLogger;
use Data::Dumper;
use UMR::SysProg::ADSObject;
use Socket;

@ISA    = qw(Exporter);
@EXPORT = qw();

# Begin-Doc
# Name: new
# Type: function
# Description: Creates object
# Syntax: $maint = new NetMaint::Util()
# End-Doc
sub new {
    my $self  = shift;
    my $class = ref($self) || $self;
    my $tmp   = {};

    &LogAPIUsage();

    return bless $tmp, $class;
}

# Begin-Doc
# Name: UserInfo
# Type: method
# Description: retrieves info for a user, also functions as an existence test
# Syntax: $info = $util->UserInfo($userid)
# End-Doc
sub UserInfo {
    my $self   = shift;
    my $userid = lc shift;

    my $ads = $self->{ads};
    if ( !$ads ) {
        $ads = new UMR::SysProg::ADSObject( use_gc => 1 )
            || die "couldn't create ads object";
        $self->{ads} = $ads;
    }

    my $info = $ads->GetAttributes($userid);

    if ($info) {
        my $name;
        ($name) = @{ $info->{displayName} };

        return { name => $name, };
    }
    return undef;
}

# Begin-Doc
# Name: CondenseEther
# Type: method
# Description: condenses an ethernet address or returns undef
# Syntax: $ether = $util->CondenseEther($ether)
# End-Doc
sub CondenseEther {
    my $self  = shift;
    my $ether = uc shift;

    $ether =~ tr/0-9A-F//cd;
    if ( length($ether) != 12 ) {
        return undef;
    }
    return $ether;
}

# Begin-Doc
# Name: CheckValidEther
# Type: method
# Description: returns error message if ethernet address is invalid
# Syntax: $msg = $util->CheckValidEther($ether)
# End-Doc
sub CheckValidEther {
    my $self      = shift;
    my $origether = shift;

    my $ether = $self->FormatEther($origether);

    if ( $origether =~ /^131\.151\.\d+\.\d+$/ ) {
        return
            "'$origether' is a UMR IP address, not an ethernet address. Look for something that looks like XX:XX:XX:XX:XX:XX";
    }

    if ( !$ether ) {
        return "invalid ethernet address";
    }
    elsif ( $ether eq "00:00:00:00:00:00" || $ether eq "FF:FF:FF:FF:FF:FF" ) {
        return "ethernet address '$ether' is subnet broadcast address (all zeroes or all ones)";
    }
    elsif ( $ether eq "02:03:8A:00:00:11" ) {
        return "ethernet address '$ether' is windows XP bridge address, use the network card instead";
    }
    elsif ( $ether eq "44:45:53:54:00:00" ) {
        return "ethernet address '$ether' is windows PPP dialup adapter address, use the network card instead";
    }
    elsif ( $ether eq "00:E0:06:09:55:66" ) {
        return "ethernet address '$ether' is a duplicated ASUS motherboard address, use a PCI ethernet card instead";
    }

    return undef;
}

# Begin-Doc
# Name: FormatEtherList
# Type: method
# Description: formats a list of ethernet address or returns undef
# Syntax: $etherlist = $util->FormatEtherList(@ethers)
# End-Doc
sub FormatEtherList {
    my $self   = shift;
    my @ethers = @_;
    my @tmp    = ();
    foreach my $ether (@ethers) {
        push( @tmp, $self->FormatEther($ether) );
    }
    return join( ", ", @tmp );
}

# Begin-Doc
# Name: FormatEther
# Type: method
# Description: formats an ethernet address or returns undef
# Syntax: $ether = $util->FormatEther($ether)
# End-Doc
sub FormatEther {
    my $self  = shift;
    my $ether = uc shift;

    $ether = $self->CondenseEther($ether);

    $ether =~ s/^(..)(..)(..)(..)(..)(..)/\1:\2:\3:\4:\5:\6/o;
    return $ether;
}

# Begin-Doc
# Name: CondenseIP
# Type: method
# Description: condenses an ip address or returns undef
# Syntax: $ip = $util->CondenseIP($ip)
# End-Doc
sub CondenseIP {
    my $self = shift;
    my $ip   = shift;

    my @tmp = split( /\./, $ip );
    return join( ".", map( int, split( /\./, $ip ) ) );
}

# Begin-Doc
# Name: IPToARPA
# Type: method
# Description: converts an ip address to it's in-addr.arpa equivalent
# Syntax: $name = $util->IPToARPA($ip)
# End-Doc
sub IPToARPA {
    my $self = shift;
    my $ip   = shift;

    $ip = $self->CondenseIP($ip);

    return join( ".", reverse split( /\./, $ip ) ) . ".in-addr.arpa";
}

# Begin-Doc
# Name: ResolveIP
# Type: method
# Description: looks up an ip in dns
# Syntax: $name = $util->ResolveIP($ip)
# End-Doc
sub ResolveIP {
    my $self = shift;
    my $ip   = shift;

    my $iaddr = inet_aton($ip);
    my $name = gethostbyaddr( $iaddr, AF_INET );

    return $name;
}

# Begin-Doc
# Name: ARPAToIP
# Type: method
# Description: converts an arpa name to it's ip equivalent
# Syntax: $name = $util->ARPAToIP($ip)
# End-Doc
sub ARPAToIP {
    my $self = shift;
    my $arpa = shift;
    my @ip;

    if ( $arpa =~ /^([\d\.]+)\.in-addr.arpa$/o ) {
        @ip = split( /\./, $1 );
    }
    my $ip = join( ".", reverse(@ip) );

    if ( $ip eq "" ) {
        $ip = "unknown";
    }

    return $ip;
}

# Begin-Doc
# Name: IPToARPAZone
# Type: method
# Description: converts an ip address to it's in-addr.arpa zone name
# Syntax: $zone = $util->IPToARPAZone($ip)
# End-Doc
sub IPToARPAZone {
    my $self = shift;
    my $ip   = shift;

    my $arpa = $self->IPToARPA($ip);

    my ( $a, $b, $c, $d, $rest ) = split( /\./, $arpa, 5 );

    if ( $ip =~ /^131\.151\./o ) {
        return join( ".", $c, $d, $rest );
    }
    elsif ( $ip =~ /^10\./o ) {
        return join( ".", $d, $rest );
    }
    elsif ( $ip =~ /^172\./o ) {
        return join( ".", $d, $rest );
    }
    else {
        return join( ".", $b, $c, $d, $rest );
    }
}

1;

