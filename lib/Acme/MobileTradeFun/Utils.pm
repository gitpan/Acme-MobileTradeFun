package Acme::MobileTradeFun::Utils;

use strict;
use warnings;

sub new {
    my ( $class, $args ) = @_;
    return bless {}, $class;
}

=head2 is_new_card

    Determines if a card is new or not

=cut

sub is_new_card {
    my ( $self, $card, $all_cards ) = @_;
    
    for my $pile ( @{ $all_cards } ) {
        return 0 if ( $card eq $pile );
    }
    return 1;
}

1;