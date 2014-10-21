package Locale::Country::Multilingual;

use warnings;
use strict;
use vars qw/$VERSION/;
use base 'Class::Data::Inheritable';

use Symbol;
use File::Spec;
use Carp;

$VERSION = '0.10';

__PACKAGE__->mk_classdata(dir => (__FILE__ =~ /(.+)\.pm/)[0]);
__PACKAGE__->mk_classdata(languages => {});
__PACKAGE__->mk_classdata('use_io_layer');

use constant CODE => 0;
use constant COUNTRY => 1;
use constant LOCALE_CODE_ALPHA_2 => 0;
use constant LOCALE_CODE_ALPHA_3 => 1;
use constant LOCALE_CODE_NUMERIC => 2;
use constant MAP_LOCALE_CODE_STR_TO_IDX => {
    LOCALE_CODE_ALPHA_2 => 0,
    LOCALE_CODE_ALPHA_3 => 1,
    LOCALE_CODE_NUMERIC => 2,
};


croak __PACKAGE__->dir, ": $!"
    unless -d __PACKAGE__->dir;

sub import {
    my $class = shift;

    return unless @_;

    my $opts = ref($_[-1]) eq 'HASH' ? pop : {};

    $class->use_io_layer($opts->{use_io_layer});

    $class->_load_data($_) for @_;
}

sub new {
    my $class = shift;
    my %args;

    %args = @_ if @_;
    return bless {
	use_io_layer => 0,
	%args,
    }, $class;
}

sub set_lang {
    my $self = shift;

    $self->{'lang'} = shift if @_;
}

sub assert_lang {
    my $self = shift;

    foreach (@_) {
	eval { $self->_load_data($_) }
	    and return $_;
    }
    return undef;
}


sub code2country {
    my ($self, $code, $lang) = @_;
    
    return unless defined $code;
    return if ($code =~ /\W/);
    
    $lang ||= $self->{lang} || 'en';
    my $language = $self->_load_data($lang);

    if ($code =~ /^\d+$/) {
        return $language->[CODE]->[LOCALE_CODE_NUMERIC]->{$code + 0};
    } elsif (length($code) == 2) {
        return $language->[CODE]->[LOCALE_CODE_ALPHA_2]->{$code};
    } elsif (length($code) == 3) {
        return $language->[CODE]->[LOCALE_CODE_ALPHA_3]->{$code};
    }
    return;
}

sub country2code {
    my ($self, $country, $codeset, $lang) = @_;
 
    return undef unless defined $country;
    $country = lc($country);
 
    $lang ||= $self->{lang} || 'en';
    my $language = $self->_load_data($lang);

    return $language->[COUNTRY]
	->[MAP_LOCALE_CODE_STR_TO_IDX->{$codeset || 'LOCALE_CODE_ALPHA_2'} || 0]
	->{$country};
}

sub all_country_codes {
    my ($self, $codeset) = @_;

    my $lang ||= $self->{lang} || 'en';
    my $language = $self->_load_data($lang);

    return keys %{
	$language->[CODE]
	->[MAP_LOCALE_CODE_STR_TO_IDX->{$codeset || 'LOCALE_CODE_ALPHA_2'} || 0]
    };
}

sub all_country_names {
    my ($self, $lang) = @_;

    $lang ||= $self->{lang} || 'en';
    my $language = $self->_load_data($lang);

    return values %{ $language->[CODE]->[LOCALE_CODE_ALPHA_2] };
}

sub _load_data {
    my ($self, $lang) = @_;

    my $languages = $self->languages;
    my $language = $languages->{$lang};

    return $language if ref $language;	# already set

    ($lang, my $fh) = $self->_open_dat($lang);
    binmode $fh, ':utf8'
	if $self->use_io_layer or ref($self) and $self->{use_io_layer};

    $language = $languages->{$lang} = [[], []];

    my $codes = $language->[CODE];
    my $countries = $language->[COUNTRY];
    while (my $line = <$fh>) {
	chomp $line;
	my ($alpha2, $alpha3, $numeric, @countries) = split(/:/, $line);
	next unless ($alpha2);
	$codes->[LOCALE_CODE_ALPHA_2]->{$alpha2} = $countries[0];
	$codes->[LOCALE_CODE_ALPHA_3]->{$alpha3} = $countries[0] if ($alpha3);
	$codes->[LOCALE_CODE_NUMERIC]->{$numeric + 0} = $countries[0] if ($numeric);
	foreach my $country (@countries) {
	    $countries->[LOCALE_CODE_ALPHA_2]->{"\L$country"} = $alpha2;
	    $countries->[LOCALE_CODE_ALPHA_3]->{"\L$country"} = $alpha3 if ($alpha3);
	    $countries->[LOCALE_CODE_NUMERIC]->{"\L$country"} = $numeric if ($numeric);
	}
    }
    close $fh;	# be a nice kid

    return $language;
}

sub _open_dat {
    my $self = shift;
    my $filename = lc(shift || '');
    my $fh = gensym;	# required before Perl 5.6
    my @errors;
    my $lang;		# stores the actual name used for loading

    # backwards compatibility
    if ($filename eq 'cn') {
	$filename = 'zh';	# zh is simplified Han Chinese (hans)
    }
    elsif ($filename eq 'tw') {
	$filename = 'zh-tw';	# zh-tw is traditional Han Chinese (hant)
    }

    # be tolerant on language identifier format as long as language comes
    # first, optionally followed by region:
    # "en_GB", "en-gb", "EN -> GB" is all the same.
    for (my @lang = split /[^A-Za-z]+/, $filename; @lang; pop @lang) {
	$lang = join('-', @lang);
	$filename = File::Spec->catfile($self->dir, "$lang.dat");
	open $fh, $filename
	    and return $lang => $fh
	    or push @errors, "$filename: $!";
    }
    # succeed or die
    croak join(', ', @errors);
}

1;

__END__

=encoding utf-8

=head1 NAME

Locale::Country::Multilingual - mapping ISO codes to localized country names

=head1 SYNOPSIS

    use Locale::Country::Multilingual;

    my $lcm = Locale::Country::Multilingual->new();
    $country = $lcm->code2country('jp');        # $country gets 'Japan'
    $country = $lcm->code2country('chn');       # $country gets 'China'
    $country = $lcm->code2country('250');       # $country gets 'France'
    $code    = $lcm->country2code('Norway');    # $code gets 'no'
    
    $lcm->set_lang('zh'); # set default language to Chinese
    $country = $lcm->code2country('cn');        # $country gets '中国'
    $code    = $lcm->country2code('日本');      # $code gets 'jp'
    
    @codes   = $lcm->all_country_codes();
    @names   = $lcm->all_country_names();
    
    # more heavy call
    my $lang = 'en';
    $country = $lcm->code2country('cn', $lang);        # $country gets 'China'
    $lang = 'zh';
    $country = $lcm->code2country('cn', $lang);        # $country gets '中国'
    
    my $CODE = 'LOCALE_CODE_ALPHA_2'; # by default
    $code    = $lcm->country2code('Norway', $CODE);    # $code gets 'no'
    $CODE = 'LOCALE_CODE_ALPHA_3';
    $code    = $lcm->country2code('Norway', $CODE);    # $code gets 'nor'
    $CODE = 'LOCALE_CODE_NUMERIC';
    $code    = $lcm->country2code('Norway', $CODE);    # $code gets '578'
    $code    = $lcm->country2code('挪威', $CODE, 'zh');    # with lang=zh
    
    $CODE = 'LOCALE_CODE_ALPHA_3';
    $lang = 'zh';
    @codes   = $lcm->all_country_codes($CODE);         # return codes with 3alpha
    @names   = $lcm->all_country_names($lang);         # get all Chinese Countries Names

=head1 DESCRIPTION

C<Locale::Country::Multilingual> is an OO replacement for
L<Locale::Country|Locale::Country>, that supports country names in several
languages.

=head2 Language Codes

A language is selected by a two-letter language code as described by
ISO 639-1 L<http://en.wikipedia.org/wiki/List_of_ISO_639-1_codes>.
This code can be amended by a two-letter region code, that is described by
ISO 3166-1 L<http://en.wikipedia.org/wiki/ISO_3166-1_alpha-2>.
This combination of language and region is also described in RFC 4646
L<http://www.ietf.org/rfc/rfc4646.txt> and RFC 4647
L<http://www.ietf.org/rfc/rfc4647.txt>, and is commonly used for
HTTP 1.1 L<http://www.ietf.org/rfc/rfc2616.txt> and the POSIX
L<setlocale(3)> function. Codes can be given in small or capital letters
and be divided by an arbitrary string of none-letter ASCII bytes (but
C<"-"> or C<"_"> is recommended).

=head2 Language Selection Fallback

In case a language code contains a region, language selection falls back to
the two-letter language code if no specific language file for the region
exists. Example: For C<"zh_CN"> selection will fall back to C<"zh"> since
there is no file F<"zh-cn.dat"> - actually C<"zh.dat"> happens to contain
the country names in Simplified (Han) Chinese.

=head1 METHODS

=head2 import

  use Locale::Country::Multilingual 'en', 'fr', {use_io_layer => 1};

The C<import> class method is called when a module is C<use>'d.
Language files can be pre-loaded at compile time, by specifying their
language codes. This can be useful when several processes are forked
from the main application, e.g. in an Apache C<mod_perl> environment -
language data that is loaded before forking, is shared by all processes.

The last argument can be a reference to a hash of options.

The only option ATM is C<use_io_layer>. See
L<Locale::Country::Multilingual::Unicode|Locale::Country::Multilingual::Unicode>
for more information.

=head2 new

  $lcm = Locale::Country::Multilingual->new;
  $lcm = Locale::Country::Multilingual->new(
    lang => 'es',
    use_io_layer => 1,
  );

Constructor method. Accepts optional list of named arguments:

=over 4

=item lang

The language to use. See L</AVAILABLE LANGAUGES> for what codes are
accepted.

=item use_io_layer

Set this C<true> if you need correct encoding behavior. See
L<Locale::Country::Multilingual::Unicode|Locale::Country::Multilingual::Unicode>
for more information.

=back

=head2 set_lang

  $lcm->set_lang('de');

Set the current language. Only argument is a language code as described in
the L</DESCRIPTION> above.

See L</AVAILABLE LANGAUGES> for what codes are accepted.

This method does not actually load the language data. Use L</assert_lang>
if you really need to know for sure if a language is supported.

=head2 assert_lang

  $lang = $lcm->assert_lang('es', 'it', 'fr');

Tries to load any of the given languages. Returns the language code for
the first language that was successfully loaded. Returns C<undef> if none
of the given languages could be loaded. Actually loads the language data,
but does not L<set the language|/set_lang>, so you probably want to use it
this way:

  $lang = $lcm->assert_lang(qw/es it fr en/)
    and $lcm->set_lang($lang)
    or die "unable to load any language\n";

=head2 code2country

  $country = $lcm->code2country('gb');
  $country = $lcm->code2country('gb', 'zh');

Turns an ISO 3166-1 code into a country name in the current language.
The default language is C<"en">.

Accepts either two-letter or a three-letter code or a 3 digit numerical code.

A language might be given as second argument to set the output language only
for this call - it does not change the current language, that was set with
L</set_lang>.

Returns the country name.

This method L<croaks|Carp> if the language is not available.

=head2 country2code

  $code = $lcm->country2code(
    'République tchèque', 'LOCALE_CODE_ALPHA_2', 'fr'
  );

Take a country name and return the two-letter code when available.
Aside from being case-insensitive the country must be written exactly the
way how L</code2country> returns it.

The second argument is optional and can be one of C<"LOCALE_CODE_ALPHA_2">,
C<"LOCALE_CODE_ALPHA_3"> and C<"LOCALE_CODE_NUMERIC">. The default is
C<"LOCALE_CODE_ALPHA2">.

The third argument is the language to use for the country name and is
optional too.

Returns an ISO-3166 code or C<undef> if search fails.

This method L<croaks|Carp> if the language is not available.

=head2 all_country_codes

  @countrycodes = $lcm->all_country_codes;
  @countrycodes = $lcm->all_country_codes($codeset);

Returns an unsorted list of all ISO-3166 codes.

The argument is optional and can be one of C<"LOCALE_CODE_ALPHA_2">,
C<"LOCALE_CODE_ALPHA_3"> and C<"LOCALE_CODE_NUMERIC">. The default is
C<"LOCALE_CODE_ALPHA2">.

=head2 all_country_names

  @countrynames = $lcm->all_country_names;
  @countrynames = $lcm->all_country_names('fr');

Returns an unsorted list of country names in the current or given locale.

=head1 AVAILABLE LANGAUGES

=over 4

=item en English

=item zh (zh-cn) Chinese Simp.

=item zh-tw Chinese Trad.

=item it Italian

=item es Spanish

=item pt Portuguese

=item de German

=item fr French

=item ja Japanese

=item no Norwegian

=back

Other languages are welcome to send by email.

=head2 Deprecated languages

Previous releases of this module offered languages C<"cn"> and C<"tw">.
Those were replaced by C<"zh"> and C<"zh-tw"> to comply with the ISO 639
standard and RFC 2616. C<"cn"> and C<"tw"> will be removed in a future
release of this package.

=head1 SUPPORTS

=over 4

=item subversion trunk

L<http://code.google.com/p/perl-locale-country-multilingual/>

=back

=head1 SEE ALSO

L<Locale::Country|Locale::Country>,
ISO 639 L<http://en.wikipedia.org/wiki/ISO_639>,
ISO 3166 L<http://en.wikipedia.org/wiki/ISO_3166>,
RFC 2616 L<http://www.ietf.org/rfc/rfc2616.txt>
RFC 4646 L<http://www.ietf.org/rfc/rfc4646.txt>,
RFC 4647 L<http://www.ietf.org/rfc/rfc4647.txt>

=head1 ACKNOWLEDGEMENTS

Thanks to michele ongaro for Italian/Spanish/Portuguese/German/French/Japanese dat files.

Thanks to Andreas Marienborg for Norwegian dat file.

=head1 AUTHOR

Fayland Lam <fayland at gmail.com>

Bernhard Graf <graf at cpan.org>

=head1 COPYRIGHT & LICENSE

Copyright 2007-2008 *AUTHOR* all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
