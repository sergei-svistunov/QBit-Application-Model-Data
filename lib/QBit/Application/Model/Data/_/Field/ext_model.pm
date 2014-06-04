package QBit::Application::Model::Data::_::Field::ext_model;

use qbit;

use base qw(QBit::Application::Model::Data::_::Field::Generate);

__PACKAGE__->mk_ro_accessors(qw(from join_fields));

sub process {
    my ($self, $data, $opts) = @_;

    my @ext_fields = @{$opts->{'options'}};
    s/^\.// foreach @ext_fields;

    my $accessor = $self->from;

    my %ext_data = map {
        my $rec = $_;
        (join($;, map {$rec->{$_}} @{$self->join_fields->[1]}) => $rec)
    } @{$self->model->$accessor->get_all(fields => [@ext_fields, @{$self->join_fields->[1]}])};

    foreach my $rec (@$data) {
        foreach my $ext_field (@ext_fields) {
            $rec->{$self->name . ".$ext_field"} =
              $ext_data{join($;, map {$rec->{$_}} @{$self->join_fields->[0]})}->{$ext_field};
        }
    }
}

TRUE;
