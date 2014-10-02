package QBit::Application::Model::Data::_::Field::Generate;

use qbit;

use base qw(QBit::Application::Model::Data::_::Field);

__PACKAGE__->abstract_methods(qw(process));

sub is_editable {FALSE}

TRUE;
