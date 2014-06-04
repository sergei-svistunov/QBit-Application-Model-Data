package QBit::Application::Model::Data::_::Expression;

use qbit;

use base qw(QBit::Class);

__PACKAGE__->mk_ro_accessors(qw(model expression));

sub get_fields {
    my ($self) = @_;

    return @{array_uniq($self->_get_fields_rec($self->expression))};
}

sub eval {
    my ($self, $rec) = @_;

    return $self->_eval_rec($self->expression, $rec);
}

sub _get_fields_rec {
    my ($self, $expr) = @_;

    if (!ref($expr)) {
        return $expr;
    } elsif (ref($expr) eq 'SCALAR') {
        return ();
    } elsif (ref($expr) eq 'HASH' && ref([%$expr]->[1]) eq 'ARRAY') {
        return (map {$self->_get_fields_rec($_)} @{[%$expr]->[1]});
    } elsif (ref($expr) eq 'ARRAY' && @$expr == 2 && ref($expr->[1]) eq 'ARRAY') {
        return (map {$self->_get_fields_rec($_)} @{$expr->[1]});
    } elsif (ref($expr) eq 'ARRAY' && @$expr == 3) {
        return ($expr->[0], $self->_get_fields_rec($expr->[2]));
    } elsif (ref($expr) eq 'REF' && ref($$expr) eq 'ARRAY') {
        return ();
    } else {
        throw Exception::BadArguments gettext('Bad field expression:\n%s', Dumper($expr));
    }
}

# 'field'                           - поле
# \$value                           - значение
# {function => [@oarameters]}       - функция
# [operator => [operand1, operand2]]- оператор
# [field => 'operator'  => \$value] - сравнение

sub _eval_rec {
    my ($self, $expr, $rec) = @_;

    if (!ref($expr)) {
        throw Exception::BadArguments gettext('Unknown field "%s"', $expr) unless exists($rec->{$expr});
        return $rec->{$expr};
    } elsif (ref($expr) eq 'SCALAR') {
        return $$expr;
    } elsif (ref($expr) eq 'HASH' && ref([%$expr]->[1]) eq 'ARRAY') {
        return $self->model->_call_function([%$expr]->[0], map {$self->_eval_rec($_, $rec)} @{[%$expr]->[1]});
    } elsif (ref($expr) eq 'ARRAY' && @$expr == 2 && ref($expr->[1]) eq 'ARRAY') {
        return $self->model->_eval_expression($expr->[0], map {$self->_eval_rec($_, $rec)} @{$expr->[1]});
    } elsif (ref($expr) eq 'ARRAY' && @$expr == 3) {
        throw Exception::BadArguments gettext('Unknown field "%s"', $expr->[0]) unless exists($rec->{$expr->[0]});
        return $self->model->_eval_field_operator($expr->[0], $rec->{$expr->[0]},
            $expr->[1], $self->_eval_rec($expr->[2], $rec));
    } elsif (ref($expr) eq 'REF' && ref($$expr) eq 'ARRAY') {
        return $$expr;
    } else {
        throw Exception::BadArguments gettext('Bad field expression:\n%s', Dumper($expr));
    }
}

TRUE;
