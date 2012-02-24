use inc::Module::Install;


RTx 'RTx-Migrate';
all_from 'lib/RTx/Migrate.pm';
readme_from 'lib/RTx/Migrate.pm';
license  'gplv2';

requires_rt '4.0.0';

my ($lib_path) = $INC{'RT.pm'} =~ /^(.*)[\\\/]/;
my $local_lib_path = "$RT::LocalPath/lib";
substitute( {
        RT_LIB_PATH => join( ' ', $local_lib_path, $lib_path ),
    },
    { sufix => '.in' },
    'sbin/rt-serializer',
    'sbin/rt-importer',
);

sign;
WriteAll;
