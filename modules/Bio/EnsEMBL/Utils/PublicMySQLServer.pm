
=head1 LICENSE

Copyright [2009-2021] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=cut

=head1 NAME

Bio::EnsEMBL::Utils::PublicMySQLServer

=head1 SYNOPSIS

  use Bio::EnsEMBL::Utils::PublicMySQLServer;

=head1 DESCRIPTION

Provides access to arguments needed to access EG and Ensembl public MySQL servers

=cut

package Bio::EnsEMBL::Utils::PublicMySQLServer;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Exception qw(warning);

use Exporter;

use base qw( Exporter );

our @EXPORT = qw(eg_host eg_port eg_user eg_pass eg_args e_host e_port e_user e_pass e_args);

use constant PUBLIC_EG_HOST => 'mysql-eg-publicsql.ebi.ac.uk';
use constant PUBLIC_EG_USER => 'anonymous';
use constant PUBLIC_EG_PASS => '';
use constant PUBLIC_EG_PORT => 4157;
use constant PUBLIC_E_HOST => 'ensembldb.ensembl.org';
use constant PUBLIC_E_USER => 'anonymous';
use constant PUBLIC_E_PASS => '';
use constant PUBLIC_E_PORT => 3306;


sub eg_host {
  return PUBLIC_EG_HOST;
}

sub eg_port {
  return PUBLIC_EG_PORT;
}

sub eg_user {
  return PUBLIC_EG_USER;
}

sub eg_pass {
  return PUBLIC_EG_PASS;
}

sub eg_args {
  return {-USER => PUBLIC_EG_USER,
		  -HOST => PUBLIC_EG_HOST,
		  -PORT => PUBLIC_EG_PORT};
}

sub e_host {
  return PUBLIC_E_HOST;
}

sub e_port {
  return PUBLIC_E_PORT;
}

sub e_user {
  return PUBLIC_E_USER;
}

sub e_pass {
  return PUBLIC_E_PASS;
}

sub e_args {
  return {-USER => PUBLIC_E_USER,
		  -HOST => PUBLIC_E_HOST,
		  -PORT => PUBLIC_E_PORT};
}

1;

