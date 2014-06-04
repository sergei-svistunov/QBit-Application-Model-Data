package QBit::Application::Model::Data::_::Field::code;

use qbit;

use base qw(QBit::Application::Model::Data::_::Field::Generate);

sub process {
    my ($self, $data, $opts) = @_;

    $_->{$self->name} = $self->{'get'}($self->model, $_) foreach @$data;
}

TRUE;
