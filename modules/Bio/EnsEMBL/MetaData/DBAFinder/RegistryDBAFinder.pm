=head1 LICENSE

Copyright [2009-2016] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.
  
=head1 NAME

Bio::EnsEMBL::MetaData::DBAFinder::RegistryDBAFinder

=head1 SYNOPSIS

=head1 DESCRIPTION

Implementation retrieving DBAdaptors from a supplied registry

=head1 AUTHOR

Dan Staines

=cut

package Bio::EnsEMBL::MetaData::DBAFinder::RegistryDBAFinder;
use base qw( Bio::EnsEMBL::MetaData::DBAFinder );
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Data::Dumper;
use strict;
use warnings;
use Log::Log4perl qw(get_logger);

=head1 SUBROUTINES/METHODS
=head2 new
Arg         : [-REGISTRY] Registry file to load from
Arg         : [-DBNAME] Name of database to restrict retrieval to
Arg         : [-PATTERN] Regexp of databases to restrict retrieval to
Arg         : [-DIVISION] Divsion to restrict retrieval to
Arg         : [-SPECIES] Species to restrict retrieval to
Description : Create a new object
Returntype  : Bio::EnsEMBL::MetaData::DBAFinder::RegistryDBAFinder
=cut
sub new {
  my ( $proto, @args ) = @_;
  my $self = $proto->SUPER::new(@args);
  ( $self->{regfile},  $self->{dbname}, $self->{pattern},
	$self->{division}, $self->{species} )
	= rearrange(
				 [ 'REGISTRY', 'DBNAME', 'PATTERN', 'DIVISION',
				   'SPECIES' ],
				 @args );
  $self->{registry} ||= 'Bio::EnsEMBL::Registry';
  $self->{logger} = get_logger();
  if ( defined $self->{regfile} ) {
      $self->{logger}->info("Loading from registry file ".$self->{regfile});
	$self->{registry}->load_all( $self->{regfile} );
  } else {
      $self->{logger}->info("Loading registry from arguments");
      $self->registry()->load_registry_from_db(@args);
      $self->registry()->set_disconnect_when_inactive(1);
  }

  return $self;
}

sub registry {
  my ($self) = @_;
  return $self->{registry};
}

=head2 get_dbas
  Description: Find DBAs to work on
  Returntype : Arrayref of Bio::EnsEMBL::DBSQL::DBAdaptor
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut
sub get_dbas {
  my ($self) = @_;
  if ( !defined $self->{dbas} ) {
	$self->{dbas} = Bio::EnsEMBL::Registry->get_all_DBAdaptors();
	$self->{logger}
	  ->info( "Found " . scalar( @{ $self->{dbas} } ) . " DBAs" );
	if ( defined $self->{dbname} ) {
	  $self->{logger}
		->info( "Restricting DBAs to DBs " . $self->{dbname} );
	  $self->{dbas} = [ grep { $_->dbc()->dbname() eq $self->{dbname} }
						@{ $self->{dbas} } ];
	}
	elsif ( defined $self->{pattern} ) {
	  $self->{logger}
		->info( "Restricting DBAs to DBs " . $self->{pattern} );

	  $self->{dbas} = [
		grep {
		  $_->dbc()->dbname() =~ m/$self->{pattern}/i
		} @{ $self->{dbas} } ];
	}
	if ( defined $self->{species} ) {
	  $self->{logger}
		->info( "Restricting DBAs to species " . $self->{species} );
	  $self->{dbas} = [ grep { $_->species() eq $self->{species} }
						@{ $self->{dbas} } ];
	}
	elsif ( defined $self->{division} ) {
	  $self->{logger}
		->info( "Restricting DBAs to division " . $self->{division} );
	  $self->{dbas} = [
		grep {
		  ref( $_->get_MetaContainer() ) eq
			'Bio::EnsEMBL::DBSQL::MetaContainer' &&
			$_->get_MetaContainer()->get_division() =~
			m/$self->{division}/i
		} @{ $self->{dbas} } ];
	}
	$self->{logger}
	  ->info( "Filtered to " . scalar( @{ $self->{dbas} } ) . " DBAs" );
  } ## end if ( !defined $self->{...})
  return $self->{dbas};
} ## end sub get_dbas

1;
