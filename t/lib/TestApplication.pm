package TestApplication;

use qbit;

use base qw(QBit::Application);

use TestApplication::Model::Users accessor        => 'users';
use TestApplication::Model::UserContacts accessor => 'user_contacts';
use TestApplication::Model::MultiplePK accessor   => 'multiple_pk';

TRUE;
