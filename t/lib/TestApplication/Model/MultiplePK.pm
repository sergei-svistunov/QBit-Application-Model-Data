package TestApplication::Model::MultiplePK;

use qbit;

use base qw(QBit::Application::Model::Data);

sub _fields_ {
    return (
        id_part1 => {type => 'number', default => TRUE, caption => 'ID part 1'},
        id_part2 => {type => 'number', default => TRUE, caption => 'ID part 2'},
    );
}

sub _pk_ {qw(id_part1 id_part2)}

TRUE;
