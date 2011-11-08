package RT::ObjectCustomFieldValue;
use strict;
use warnings;

sub Dependencies {
    my $self = shift;
    my ($walker, $deps) = @_;

    $self->SUPER::Dependencies($walker, $deps);

    $deps->Add( out => $self->CustomFieldObj );
    $deps->Add( out => $self->Object );
}

sub PreInflate {
    my $class = shift;

    my ($importer, $uid, $data) = @_;

    if (defined $data->{LargeContent}) {
        my ($ContentEncoding, $Content) = $class->_EncodeLOB(
            $data->{LargeContent},
            $data->{ContentType},
        );
        $data->{ContentEncoding} = $ContentEncoding;
        $data->{LargeContent} = $Content;
    }

    return $class->SUPER::PreInflate( $importer, $uid, $data );
}

1;
