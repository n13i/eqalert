package EQAlert::Alert;

use strict;
use warnings;
use utf8;
use Carp;
use version; our $VERSION = qv("0.01");

use constant LV_INFO  => 1;
use constant LV_WARN  => 2;
use constant LV_ALERT => 4;

sub new
{
    my $class = shift;
    my $self = shift || {
        level => undef,
        month => undef,
        date => undef,
        hour => undef,
        minute => undef,
        second => undef,
        epicenter => undef,
        magnitude => undef,
        epicenter_lon => undef,
        epicenter_lat => undef,
        epicenter_depth => undef,
        scale => undef,
    };
    return bless $self, $class;
}

sub scale
{
    my $self = shift;
    my $s = $self->{scale};
    $s =~ s/\.1/弱/;
    $s =~ s/\.9/強/;
    return $s;
}

sub equals
{
    my $self = shift;
    my $target = shift || return 0;

    foreach(qw(level month date hour minute second epicenter magnitude epicenter_lon epicenter_lat epicenter_depth scale))
    {
        next if(!defined($self->{$_}) && !defined($target->{$_}));
        return 0 if(defined($self->{$_}) && !defined($target->{$_}));
        return 0 if(!defined($self->{$_}) && defined($target->{$_}));
        if($self->{$_} ne $target->{$_})
        {
            return 0;
        }
    }

    return 1;
}

