package Acme::MobileTradeFun::NewParser;

use strict;
use warnings;
use Mojo::DOM;
use Log::Log4perl qw/:easy/;
use URI::Encode qw/uri_decode/;
use Acme::MobileTradeFun::Utils;
use Data::Dumper;

sub new {
    my ( $class, $args ) = @_;
    my $self = {};
    $self->{ utils } = Acme::MobileTradeFun::Utils->new();
    return bless $self, $class;
}

=head2 parse_data

    parses HTML, populates $self->{ data } hash

=cut

sub parse_data {
    my ( $self, $html, $all_cards ) = @_;

    my $card_found = 0;
    my $dom = Mojo::DOM->new( $html );
    my @new_cards;

    for my $card ( $dom->find( 'section.card' )->each ) {
        my $category = ( $card->find( 'span' )->each )[0]->text;
        my @links = $card->find( 'a' )->each;
        
        my $name = $links[1]->text;
        my $rarity = $links[2]->text;
        $rarity =~ s/\(//;
        $rarity =~ s/\)//;
        my $link = $links[3]->attr( 'href' );

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

        if ( $self->{ utils }->is_new_card( $card_name, $all_cards ) ) {
            my $elem = { name => $card_name, url => $url };
            push @new_cards, $elem;
        }
    }
    return ( $card_found, @new_cards );
}

1;