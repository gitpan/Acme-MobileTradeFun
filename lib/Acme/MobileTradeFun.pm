package Acme::MobileTradeFun;

use 5.006;
use strict;
use warnings;
use Data::Dumper;
use Carp;
use LWP::Simple;
use File::Path qw/make_path/;
use Log::Log4perl qw/:easy/;
use URI::Encode qw/uri_decode/;
use AnyEvent;
use AnyEvent::HTTP;
use Mojo::DOM;
use Encode;

=head1 NAME

Acme::MobileTradeFun - Needlessly OO module to scrape card images off of the
MobileTradeFun site

=head1 VERSION

Version 0.11

=cut

our $VERSION = '0.11';


=head1 SYNOPSIS

I recently found a site called MobileTradeFun (or MobaTreFun for short), where
people can search the value of cards from mobile games, such as idolmaster.

http://mobile-trade.jp

This site seems to contain the "official" card images as they show up on the
mobile devices in Japan.  This module basically lets you specify a game, and
scrapes all the high quality cards off of the site.

Note that card names are stored in Japanese, as each card contains certain
attributes such as category, card name and rarity.  Without these attributes,
cards cannot be identified uniquely.

The interface of the module is pretty simple.  You construct a hashref of args,
and pass it onto the class method run() which will take care of the rest.

    use Acme::MobileTradeFun;

    my $args = {
        game        => 'idolmaster',
    };

    my $foo = Acme::MobileTradeFun->run( $args );
    
Here are the overwritable defaults in the hashref.  Currently 4 games are
supported: bahamut, idolmaster, saintseiya and gangroad.

    game        => '',
    base_url    => 'http://mobile-trade.jp/fun',
    php_script  => 'card.php',
    row         => 100,     # how many cards per page
    page        => 1,       # which page to start from
    output_dir  => '/tmp',  # where to save the images
    debug       => 0,


=head1 SUBROUTINES/METHODS

=head2 new

    The constructor

=cut

sub new {
    my ( $class, $args ) = @_;
    my $self = {};
    bless $self, $class;
    $self->init( $args );
    return $self;
}

=head2 init

    Sets up default args, overrides, validates args etc

=cut

sub init {
    my ( $self, $args ) = @_;
    
    croak "not a hashref" if ( $args && ref( $args ) ne "HASH" );

    $self->{ opts } = {
        game        => '',
        base_url    => 'http://mobile-trade.jp/fun',
        php_script  => 'card.php',
        row         => 100,
        page        => 1,
        output_dir  => '/tmp',
        debug       => 0,
    };

    %{ $self->{ opts } } = ( %{ $self->{ opts } }, %{ $args } ) if ( $args );
    croak "game not specified" unless( $self->{ opts }->{ game } );
    
    Log::Log4perl->easy_init($DEBUG) if ( $self->{ opts }->{ debug } );
    my $out_dir = $self->{ opts }->{ output_dir } . "/" . $self->{ opts }->{ game };
    make_path( $out_dir ) unless( -d $out_dir );
    $self->{ opts }->{ output_dir } = $out_dir; # appending game name as subdir
}

=head2 run

    The driver method.  Calls new then other methods to drive.

=cut

sub run {
    my ( $class, $args ) = @_;
    my $self = $class->new( $args );
    $self->load_existing_cards();
    $self->fetch_cards();
    return $self;
}

=head2 load_existing_cards

    Loads existing cards into $self->{ cards } array.

=cut

sub load_existing_cards {
    my $self = shift;

    my $dir = $self->{ opts }->{ output_dir };
    opendir( my $dh, $dir );
    
    while( my $file = readdir( $dh ) ) {
        # need to decode UTF-8 to internal format
        $file = decode( 'UTF-8', $file );
        push @{ $self->{ cards } }, $file if ( $file =~ /\.jpg$/ );
    }
}

=head2 is_new_card

    Determines if a card is new or not

=cut

sub is_new_card {
    my ( $self, $card ) = @_;
    
    my @cards = @{ $self->{ cards } };
    
    for my $pile ( @cards ) {
        return 0 if ( $card eq $pile );
    }
    return 1;
}

=head2 fetch_cards

    Wrapper method to initiate the fetching of cards

=cut

sub fetch_cards {
    my $self = shift;
    
    my $page        = $self->{ opts }->{ page };
    my $base_url    = $self->{ opts }->{ base_url };
    my $script      = $self->{ opts }->{ php_script };
    my $row         = $self->{ opts }->{ row };
    my $game        = $self->{ opts }->{ game };
    my $dir         = $self->{ opts }->{ output_dir };
    
    # scrape the pages from PHP, populate all the card data
    while( 1 ) {
        my $url = "$base_url/$game/$script?row=$row&page=$page";
        my $data = get( $url );
        my $cards = $self->parse_data( $data );
        DEBUG "scraping $url.  $cards found.";
        last unless ( $cards );
        $page++;
    }
    
    unless( $self->{ data } ) {
        DEBUG "no card to fetch, exiting";
        return;
    }

    my $cv = AE::cv {
        DEBUG "fetched all cards!";
    };

    for my $key ( @{ $self->{ data } } ) {
        $cv->begin;
        my $url = $key->{ url };
        http_get $url, sub {
            my ( $data, $hdr ) = @_;
            if ( $hdr->{ Status } =~ /^2/ ) {
                my $file = "$dir/$key->{ name }";
                open( my $fh, ">", $file ) or croak "couldn't open $file: $!";
                print $fh $data;
                close $fh or croak "couldn't close $file: $!";
            }
            else {
                DEBUG "something went wrong with $url";
            }
            $cv->end;
        }
    }
    $cv->recv;
}

=head2 parse_data

    parses HTML, populates $self->{ data } hash

=cut

sub parse_data {
    my ( $self, $html ) = @_;

    my $card_found = 0;
    my $dom = Mojo::DOM->new( $html );
    
    for my $table ( $dom->find( 'table.card_search_result_table' )->each ) {
        my $category;

        # for each span in the table, I am looking for style attribute with
        # color in it -- this should be the tag with category in it
        for my $span ( $table->find( 'span' )->each ) {
            my $color = $span->{ style };
            $category = $span->text if ( $color && $color =~ /color/ );
        }

        my @links = $table->find( 'a' )->each;
        my $name = $links[0]->text;
        my $rarity = $links[1]->text;
        my $link = $links[2]->attr( 'href' );
        
        unless ( $category && $name && $rarity && $link ) {
            my $message = "Something is missing:";
            $message .= " $category" if ( $category );
            $message .= " $name" if ( $name );
            $message .= " $rarity" if ( $rarity );
            $message .= " $link" if ( $link );
            DEBUG $message;
            next;
        }
        
        my $url = uri_decode( $link );
        my $card_name = "[$category]$name($rarity).jpg";
        $card_name =~ s/\s+//g; # sometimes bunch of spaces creep in
        $card_found++;

        if ( $self->is_new_card( $card_name ) ) {
            my $elem = { name => $card_name, url => $url };
            push @{ $self->{ data } }, $elem;
        }
    }

    return $card_found;
}

=head1 AUTHOR

Satoshi Yagi, C<< <satoshi.yagi at yahoo.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-app-mobiletradefun at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Acme-MobileTradeFun>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Acme::MobileTradeFun


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Acme-MobileTradeFun>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Acme-MobileTradeFun>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Acme-MobileTradeFun>

=item * Search CPAN

L<http://search.cpan.org/dist/Acme-MobileTradeFun/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2012-2013 Satoshi Yagi.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut

1; # End of Acme::MobileTradeFun
