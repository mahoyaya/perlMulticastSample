#!/usr/bin/env perl
use strict;
use warnings;

use IO::Select;
use IO::Socket::INET;
use Socket qw(SOL_SOCKET SO_RCVBUF IPPROTO_IP IP_TTL INADDR_ANY  IP_ADD_MEMBERSHIP IP_DROP_MEMBERSHIP IP_MULTICAST_LOOP IP_MULTICAST_IF IP_MULTICAST_TTL pack_ip_mreq);

my $sock;
socket($sock, AF_INET, SOCK_DGRAM, 0) || die "Cannot open socket: $!";
print "Opening datagram socket OK!\n";

setsockopt($sock, SOL_SOCKET, SO_REUSEADDR, 1) or die "setsockopt: $!"; # reuse timewait session
print "Setting SO_REUSEADDR OK!\n";

if ( ! $^O eq "MSWin32" ) {
    setsockopt($sock, SOL_SOCKET, SO_REUSEPORT, 1) or die "setsockopt: $!"; # reuse timewait session at same port number
    print "Setting SO_REUSEPORT OK!\n";
} else {
    print "Setting SO_REUSEPORT Skipping\n";
}

setsockopt($sock, SOL_SOCKET, SO_RCVBUF, 64*1024) or die "setsockopt: $!";
print "Setting SO_RCVBUF OK!\n";


########
# BIND START
my $multiaddr = inet_aton("224.0.0.251");
my $source = inet_aton("192.168.56.101");
my $interface = INADDR_ANY;
my $ip_mreq = pack_ip_mreq($multiaddr, $source);

my $multi_sock_addr = sockaddr_in(5353, $multiaddr);
my $bind_sock_addr = sockaddr_in(5353, $interface);
bind($sock, $bind_sock_addr) or die "bind: $!";
print "Bind OK!\n";
# BIND END
########



# マルチキャストグループに加入
setsockopt($sock, IPPROTO_IP, IP_MULTICAST_LOOP, 1) or die "setsockopt: $!"; # resent send packet to loopback interface. default 0, disable
print "Setting IP_MULTICAST_LOOP OK!\n";

setsockopt($sock, IPPROTO_IP, IP_MULTICAST_IF, $source) or die "setsockopt: $!"; # set interface(ip address)
print "Setting IP_MULTICAST_IF OK!\n";

setsockopt($sock, IPPROTO_IP, IP_ADD_MEMBERSHIP, $ip_mreq) or die "setsockopt: $!";
print "Join the multicast group OK!\n";

setsockopt($sock, IPPROTO_IP, IP_MULTICAST_TTL, 1) or die "setsockopt: $!"; # set multicast ttl. default 1

print "Receive buffer is ", unpack("I", getsockopt($sock, SOL_SOCKET, SO_RCVBUF)), " bytes\n";
print "IP TTL is ", unpack("I", getsockopt($sock, IPPROTO_IP, IP_TTL)), "\n";
print "IP Multicast TTL is ", unpack("I", getsockopt($sock, IPPROTO_IP, IP_MULTICAST_TTL)), "\n";


my $data = "0123456789";
print "request sending...";
send($sock, $data, 0, $multi_sock_addr) || die "send failed $!";

my $self = Properties->new;

my $rin = '';
vec($rin, fileno($sock), 1) = 1;
while (1) {
    print "waiting data...";
    # データを待つ
    my ($nfound, $timeleft) = select(my $rout=$rin,undef,undef,$self->{TIMEOUT});

    if ($nfound) {
        my $max = 512;
        $max = 1410 if $self->{EDNS} > 0; # EDNSの推奨値1280-1410Bytes
        recv($sock, my  $rbuff, $max, 0) || die("recv failed $!");
        print length($rbuff) . " Byte(s) data received.";

        my @ary = $rbuff =~ m/(.{1})/sg;
        dumpArray(\@ary);

    } else {
        warn "timeout.";
    }
    sleep 1;
}
#sleep 300;

print "Exit the multicast group\n";

# マルチキャストグループから削除
setsockopt($sock, IPPROTO_IP, IP_DROP_MEMBERSHIP, $ip_mreq) or die "setsockopt: $!";

exit;

sub dumpArray {
    # オクテットデータの配列を受け取り、文字か16進数で表示する
    #my $self = shift;
    my $aref = shift;
    my $prefix = shift;
    my $str = undef;
    for ( @$aref ) {
        my $b = unpack("C", $_);
        if ( $b > 47 && $b < 58 || $b > 64 && $b < 91 || $b > 96 && $b < 123 ) {
            #可読文字ならそのまま出力
            $str .= " " . $_;
        } else {
            #可読不可ならHEXに変換
            $str .= uc(unpack("H*", $_));
        }
        $str .= " ";
    }
    $prefix ? $str = $prefix . " " . $str : 1;
    warn "dumpArray:" .  $str;
    return;
}

#############################################################
package Properties;

sub new {
    my $class = shift;
    my $self = {
        TIMEOUT => 300,
        EDNS => 1,
    };
    bless $self, $class;
    return $self;
}


sub makeIGMPReport {
    my $self = shift;
    my $ver = "0001"; # 4bit, igmp version
    my $type = "0010"; # 4bit, igmp report/query 0001
    my $unused = "00000000"; # 8bit
    my $checksum = ""; # 16bit, checksum
    my $gaddress = inet_aton("224.0.0.251"); # 32bit, group address
}

1;
