#!/usr/bin/perl
use warnings;
use strict;
use utf8;

use FindBin qw($Bin);
use Encode;
use YAML;
use IO::Handle qw(autoflush);
use Math::Round;
use AnyEvent::Twitter::Stream;

use FindBin::libs;
use EQAlert;
use EQAlert::Alert;

use constant ALERT_EEW     => 1;
use constant ALERT_NOTIFY  => 1;
use constant ALERT_WARNING => 1;
use constant ALERT_EEW => 1;

open FH, '<:encoding(utf8)', $Bin . '/../conf/config.yaml';
my $conf = YAML::Load(join('', <FH>)) or die;
close FH;

binmode STDIN, ':encoding(utf8)';
binmode STDOUT, ':encoding(utf8)';
binmode STDERR, ':encoding(utf8)';
autoflush STDOUT;

my $follow_users = $conf->{follow_users};

my $last_eew_epicenter = undef;
my $last_eew_alert = undef;


system(sprintf('"%s" "%s" "%s" &',
    $Bin . '/../utils/talk',
    '起動します',
    $Bin . '/../sounds/' . $conf->{sounds}->{notify},
));

my $reconn_wait_sec = 0;
my $reconn_try_count = 0;

while (1)
{
    my $cv = AE::cv;
    my $is_connected = 0;
    my $listener = AnyEvent::Twitter::Stream->new(
        consumer_key    => $conf->{twitter}->{consumer_key},
        consumer_secret => $conf->{twitter}->{consumer_secret},
        token           => $conf->{twitter}->{access_token},
        token_secret    => $conf->{twitter}->{access_token_secret},
        method   => 'filter',
        follow   => join(',', @{$follow_users}),
        on_tweet => sub {
            my $tweet = shift;
            $is_connected = 1 unless $is_connected;
            &on_tweet($tweet);
        },
        on_keepalive => sub {
            warn 'ping';
            $is_connected = 1 unless $is_connected;
        },
        on_delete => sub {
            # callback executed when twitter send a delete notification
            my ($tweet_id, $user_id) = @_;
        },
        on_error => sub {
            my $error = shift;
            warn "ERROR: $error";
            $cv->send;
        },
        timeout => 90,
    );
    $cv->recv;

    undef $listener;

    # 再接続まで待つ
    # https://dev.twitter.com/docs/streaming-api/user-streams/suggestions#algorithms
    if($is_connected == 1)
    {
        $reconn_try_count = 0;
    }
    $reconn_try_count++;

    if($reconn_try_count == 1)
    {
        # 最初は20～40秒のランダム
        $reconn_wait_sec = 20 + round(rand(20));
    }
    else
    {
        # 接続できずリトライする場合，倍にしていく
        $reconn_wait_sec *= 2;
    }
    # 300秒を超える場合，240～300秒のランダム
    if($reconn_wait_sec > 300)
    {
        $reconn_wait_sec = 240 + round(rand(60));
    }

    warn "Waiting for reconnection " . $reconn_wait_sec . "sec";
    my $wait_cv = AE::cv;
    my $wait_t = AE::timer $reconn_wait_sec, 0, $wait_cv;
    $wait_cv->recv;
}

# tweet受信時
sub on_tweet
{
    my $tweet = shift;
    #print Dump($tweet);

    foreach(@{$follow_users})
    {
        if($tweet->{user}->{id} eq $_)
        {
            printf "By: %s\n", $tweet->{user}->{screen_name};
            printf "Message: %s\n\n", $tweet->{text};
            &check_alert($tweet);
            &check_eew_for_public_users($tweet);
        }
    }
}

# 一般利用者向け緊急地震速報の発表検出
sub check_eew_for_public_users
{
    my $tweet = shift || return;

    if($tweet->{user}->{id} eq $conf->{eew_public_user} &&
       $tweet->{text} =~ /発表を検出/)
    {
        &got_eew_for_public_users;
    }
}

sub got_eew_for_public_users
{
    # 発表検出時点で最後に受信したアラートを使う
    my $alert = $last_eew_alert;
    my $epicenter;
    if(!defined($alert))
    {
        $epicenter = '不明';
    }
    else
    {
        $epicenter = $alert->{epicenter};
    }

    $alert->{level} = EQAlert::Alert::LV_ALERT;
    &notify($alert);
}

# 受信したtweetの解析・通知
sub check_alert
{
    my $tweet = shift || return;
    my $alert = EQAlert::parse($tweet->{text}, $tweet->{user}->{screen_name});
    print Dump($alert);

    if(!defined($alert))
    {
        printf "text parse failed: %s: %s\n",
            $tweet->{user}->{screen_name}, $tweet->{text};
        return;
    }

    &notify($alert);
}

sub notify
{
    my $alert = shift;
    return if(!defined($alert));
    return if($alert->{level} <= 0);

    my $talk = undef;
    my $sound = undef;

    if($alert->{level} >= EQAlert::Alert::LV_ALERT)
    {
        # 一般向け緊急地震速報発報時
        $talk = '緊急地震速報、' . $alert->{epicenter} . 'で地震。';
        $sound = $conf->{sounds}->{alert};
    }
    elsif($alert->{level} >= EQAlert::Alert::LV_WARN)
    {
        # 地震速報の場合
        $last_eew_alert = $alert;

        $talk = sprintf "震度%s、%s、M%s。",
            $alert->scale,
            $alert->{epicenter},
            $alert->{magnitude};

        if($alert->scale >= $conf->{warning_scale})
        {
            $sound = $conf->{sounds}->{warning};
        }
        else
        {
            $sound = $conf->{sounds}->{notify};
        }

    }
    elsif($alert->{level} >= EQAlert::Alert::LV_INFO)
    {
        # 地震情報の場合
        if($alert->scale >= $conf->{notify_scale})
        {
            $sound = $conf->{sounds}->{info};
            my $talk = sprintf "地震情報、%d時%d分、最大震度%s、%s、深さ%sキロ、マグニチュード%s。",
                $alert->{hour},
                $alert->{minute},
                $alert->scale,
                $alert->{epicenter},
                $alert->{epicenter_depth},
                $alert->{magnitude};
        }
    }

    if(defined($talk))
    {
        printf "＞%s\n", $talk;
        system(sprintf('"%s/../utils/talk" "%s" "%s/../sounds/%s" &',
            $Bin,
            $talk,
            $Bin, $sound,
        ));
    }

    system("$Bin/../utils/send_to_chumby " .
        sprintf('"%d" "%s" "%02d" "%02d" "%s" "%s" "%s"',
            $alert->{level},
            $alert->{scale},
            $alert->{hour},
            $alert->{minute},
            $alert->{epicenter},
            $alert->{epicenter_depth},
            $alert->{magnitude},
        ) . " &");
}

