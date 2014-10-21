#!perl -T

use utf8;

use Test::More tests => 2;

use Locale::Country::Multilingual {use_io_layer => 1};

my $lcm = Locale::Country::Multilingual->new(lang => 'de');

my $country = $lcm->code2country('fo');
is($country, 'Färöer', "internal encoding looks fine");
is(uc($country), 'FÄRÖER', "locale letters handled correctly");

