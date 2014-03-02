package Acme::MobileTradeFun::OldParser;

use strict;
use warnings;
use Mojo::DOM;
use Log::Log4perl qw/:easy/;
use URI::Encode qw/uri_decode/;
use Acme::MobileTradeFun::Utils;

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

        if ( $self->{ utils }->is_new_card( $card_name, $all_cards ) ) {
            my $elem = { name => $card_name, url => $url };
            push @new_cards, $elem;
        }
    }
    return ( $card_found, @new_cards );
}

1;