package EQAlert;

use warnings;
use strict;
use utf8;

use Exporter;
use Carp;
use version; our $VERSION = qv("0.01");

use vars qw(@ISA @EXPORT);
@ISA = qw(Exporter);
@EXPORT = qw(parse);

use YAML;
use DateTime;

use FindBin::libs;
use EQAlert::Alert;

sub parse
{
    my $source = shift || return undef;
    my $format = shift;

    if($format eq 'test')
    {
        return &parse_test($source);
    }
    elsif($format eq 'quake_alert')
    {
        return &parse_quake_alert($source);
    }
    elsif($format eq 'eew_jp')
    {
        return &parse_eew_jp($source);
    }
    elsif($format eq 'zishin3255')
    {
        return &parse_zishin3255($source);
    }
    elsif($format eq 'earthquake_jp')
    {
        return &parse_earthquake_jp($source);
    }
    elsif($format eq 'yurekuru')
    {
        return &parse_yurekuru($source);
    }

    return undef;
}

sub parse_earthquake_jp
{
    my $source = shift || return undef;
    my $alert = new EQAlert::Alert;

    # 【気象庁情報】12日20時00分頃 福島県浜通り近辺(N37.1/E140.7)にて最大震度3(M3.8)の地震が発生。震源の深さは20km。( http://j.mp/i2DpOd ) #saigai #eqjp #earthquake #jishin

    # 【速報LV1】22日22時23分頃 千葉県銚子市近辺(N35.6/E140.8)にて(推定M4)の 地震が発生。震源の深さは推定47.9km。( http://j.mp/i1MEpw ) #saigai #eqjp #earthquake #jishin
    # ［気象庁情報］17日　14時25分頃　茨城県北部（N36.8/E140.6）にて　最大震 度1（M3）の地震が発生。　震源の深さは10km。( http://t.co/t2OpOAIR ) #saigai #jishin #earthquake
    if($source =~ /^[［【](気象庁情報)[］|】](\d+?)日　?(\d+?)時(\d+?)分頃[\s　](\w+?)　?(?:近辺)?[\(（]([NS])([\d\.]+?)\/([EW])([\d\.]+?)[\)）]にて　?最大震度(\d[強弱]?)[\(（](?:推定)?M([\d\.]+?)[\)）]の地震が発生。　?震源の深さは(?:推定)?(\d+?)km/)
    {
        if($1 eq '気象庁情報')
        {
            $alert->{level} = EQAlert::Alert::LV_INFO;
        }
        elsif($1 =~ /^速報/)
        {
            $alert->{level} = EQAlert::Alert::LV_WARN;
        }

        #$alert->{month} = DateTime->now->month;
        $alert->{date} = int($2);
        $alert->{hour} = int($3);
        $alert->{minute} = int($4);
        $alert->{epicenter} = $5;
        $alert->{epicenter_lat} = ($6 eq 'N' ? $7 : -$7);
        $alert->{epicenter_lon} = ($8 eq 'E' ? $9 : -$9);
        $alert->{scale} = $10;
        $alert->{magnitude} = $11;
        $alert->{epicenter_depth} = $12;

        $alert->{scale} =~ s/強/\.9/;
        $alert->{scale} =~ s/弱/\.1/;

        return $alert;
    }

    return undef;
}

sub parse_zishin3255
{
    my $source = shift || return undef;

    return undef if($source =~ /^RT/);

    my $alert = new EQAlert::Alert;

    # ■■緊急地震速報■■ 福島県浜通り地方で地震　最大震度 ４ [詳細] 2011/4/12 0:43:14発生　M4.5 深さ10km 第3報　　東京到達時刻：0:43:59 (あと約45秒) #jishin #earthquake #eqjp


    $source =~ tr/０-９．/0-9./;

    $alert->{level} = EQAlert::Alert::LV_WARN;

    if($source =~ /\s(\w+)で地震/)
    {
        $alert->{epicenter} = $1;
    }
    if($source =~ /最大震度\s(\d[弱強]?)/)
    {
        $alert->{scale} = $1;
        $alert->{scale} =~ s/強/\.9/;
        $alert->{scale} =~ s/弱/\.1/;
    }
    if($source =~ /\d{4}\/(\d+)\/(\d+)\s(\d+)\:(\d+)\:(\d+)発生/)
    {
        $alert->{month}  = int($1);
        $alert->{date}   = int($2);
        $alert->{hour}   = int($3);
        $alert->{minute} = int($4);
        $alert->{second} = int($5);
    }
    if($source =~ /M([\d\.]+?)\s深さ(\d+)km/)
    {
        $alert->{magnitude} = $1;
        $alert->{epicenter_depth} = $2;
    }

    return $alert;
}

sub parse_eew_jp
{
    my $source = shift || return undef;
    my $alert = new EQAlert::Alert;

    # 地震速報 2011/04/12 00:21頃、茨城県北部の深さ10kmでマグニチュード4の地震が発生しました。予想される最大震度は震度3です。

    $alert->{level} = EQAlert::Alert::LV_WARN;

    if($source =~ /\d{4}\/(\d{2})\/(\d{2})\s(\d{2})\:(\d{2})頃、(\w+)の深さ/)
    {
        $alert->{month}  = int($1);
        $alert->{date}   = int($2);
        $alert->{hour}   = int($3);
        $alert->{minute} = int($4);
        $alert->{epicenter} = $5; 
    }
    if($source =~ /深さ(\d+)km/)
    {
        $alert->{epicenter_depth} = int($1);
    }
    if($source =~ /マグニチュード([\d\.]+)/)
    {
        $alert->{magnitude} = $1;
    }
    if($source =~ /震度(\d[弱強]?)/)
    {
        $alert->{scale} = $1;
        $alert->{scale} =~ s/強/\.9/;
        $alert->{scale} =~ s/弱/\.1/;
    }

    return $alert;
}

sub parse_quake_alert
{
    my $source = shift || return undef;
    my $alert = new EQAlert::Alert;

    # 平成２３年 ４月１１日２３時０２分２３秒 福島県浜通り Ｍ３．４程度 北緯３６．９度 東経１４０．７度 深さ１０ｋｍ 最大震度 ３程度 と推定

    $source =~ tr/０-９．/0-9./;
    #printf "%s\n", $source;

    $alert->{level} = EQAlert::Alert::LV_WARN;

    if($source =~ /(\d{1,2})月\s*(\d{1,2})日(\d{1,2})時(\d{1,2})分(\d{1,2})秒\s([^\s]+)\sＭ(\d\.\d)程度/)
    {
        $alert->{month}     = int($1);
        $alert->{date}      = int($2);
        $alert->{hour}      = int($3);
        $alert->{minute}    = int($4);
        $alert->{second}    = int($5);
        $alert->{epicenter} = $6;
        $alert->{magnitude} = $7;
    }
    if($source =~ /([北南])緯(\d+\.\d+)度\s([東西])経(\d+\.\d+)度\s深さ(\d+)ｋｍ/)
    {
        if($1 eq '北')
        {
            $alert->{epicenter_lat} = $2;
        }
        elsif($1 eq '南')
        {
            $alert->{epicenter_lat} = -$2;
        }
        if($3 eq '東')
        {
            $alert->{epicenter_lon} = $4;
        }
        elsif($3 eq '西')
        {
            $alert->{epicenter_lon} = -$4;
        }
        $alert->{epicenter_depth} = $5;
    }
    if($source =~ /震度\s?(\d[強弱]?)/)
    {
        $alert->{scale} = $1;
        $alert->{scale} =~ s/強/\.9/;
        $alert->{scale} =~ s/弱/\.1/;
    }

    return $alert;
}

sub parse_yurekuru
{
    my $source = shift || return undef;
    my $alert = new EQAlert::Alert;

    # [EEW] ID：ND20120327200050 SEQ：final 震源地：岩手県沖 緯度：39.8 経度：142.3 震源深さ：10km 発生日時：2012/03/27 20:00:42 マグニチュード：6.1 最大震度：５弱 #yurekuru

    $source =~ tr/０-９．/0-9./;
    #printf "%s\n", $source;

    $alert->{level} = EQAlert::Alert::LV_WARN;

    if($source =~ /震源地：([^\s]+)\s/)
    {
        $alert->{epicenter} = $1;
    }
    if($source =~ /緯度：([\d\.]+)\s経度：([\d\.]+)\s/)
    {
        $alert->{epicenter_lat} = $1;
        $alert->{epicenter_lon} = $2;
    }
    if($source =~ /震源深さ：([\d]+)km\s/)
    {
        $alert->{epicenter_depth} = $1;
    }
    if($source =~ /発生日時：\d{4}\/(\d{2})\/(\d{2})\s(\d{2})\:(\d{2})\:(\d{2})\s/)
    {
        $alert->{month}  = int($1);
        $alert->{date}   = int($2);
        $alert->{hour}   = int($3);
        $alert->{minute} = int($4);
        $alert->{second} = int($5);
    }
    if($source =~ /マグニチュード：(\d\.\d)\s/)
    {
        $alert->{magnitude} = $1;
    }
    if($source =~ /最大震度：(\d[強弱]?)/)
    {
        $alert->{scale} = $1;
        $alert->{scale} =~ s/強/\.9/;
        $alert->{scale} =~ s/弱/\.1/;
    }

    return $alert;
}

sub parse_test
{
    my $source = shift || return undef;

    my $alert = new EQAlert::Alert;
    
    my @list = split /\s/, $source;

    my $i = 0;
    foreach(qw(level month date hour minute second epicenter magnitude epicenter_lat epicenter_lon epicenter_depth scale))
    {
        #printf "%d:%s\n", $i, $list[$i];
        if($list[$i] ne '-')
        {
            $alert->{$_} = $list[$i];
        }
        $i++;
    }

    return $alert;
}

