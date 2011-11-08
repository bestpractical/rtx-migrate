package RT::Attachment;
use strict;
use warnings;

sub Dependencies {
    my $self = shift;
    my ($walker, $deps) = @_;

    $self->SUPER::Dependencies($walker, $deps);
    $deps->Add( out => $self->TransactionObj );
}

sub PreInflate {
    my $class = shift;

    my ($importer, $uid, $data) = @_;

    if (defined $data->{Content}) {
        my ($ContentEncoding, $Content) = $class->_EncodeLOB(
            $data->{Content},
            $data->{ContentType},
            $data->{Filename}
        );
        $data->{ContentEncoding} = $ContentEncoding;
        $data->{Content} = $Content;
    }

    return $class->SUPER::PreInflate( $importer, $uid, $data );
}

1;
