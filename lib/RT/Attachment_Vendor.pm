package RT::Attachment;
use strict;
use warnings;

sub FindDependencies {
    my $self = shift;
    my ($walker, $deps) = @_;

    $self->SUPER::FindDependencies($walker, $deps);
    $deps->Add( out => $self->TransactionObj );
}

sub Serialize {
    my $self = shift;
    my %store = $self->SUPER::Serialize;

    $store{Content} = $self->Content;
    delete $store{ContentEncoding};

    return %store;
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
