package TestApplication::Model::RBAC;

use qbit;

use base qw(QBit::Application::Model::RBAC);

sub get_cur_user_roles {
    my ($self) = @_;

    return $self->get_option(cur_user => {id => 0})->{'id'} == 0 ? {1 => 'Test admin role'} : {2 => 'Test role'};
}

sub get_roles_rights {
    my ($self, %opts) = @_;

    my @result;
    foreach ($opts{'role_id'} ? @{$opts{'role_id'}} : [1,2]) {
        push(@result, $_ == 1 ? {role_id => 1, right => 'users_view_all'} : ());
    }

    return \@result;
}

# ==================================================================================
package TestApplication;

use qbit;

use base qw(QBit::Application);

BEGIN {
    TestApplication::Model::RBAC->import(accessor => 'rbac');
}

use TestApplication::Model::Users accessor        => 'users';
use TestApplication::Model::UserContacts accessor => 'user_contacts';
use TestApplication::Model::MultiplePK accessor   => 'multiple_pk';

TRUE;
