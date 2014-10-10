=pod
=head1 LICENSE

Copyright [2009-2014] EMBL-European Bioinformatics Institute

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

=pod

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.
 
=cut

package Bio::EnsEMBL::Utils::MetaData::DBAFinder::RegistryDBAFinder;
use base qw( Bio::EnsEMBL::Utils::MetaData::DBAFinder );
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Data::Dumper;
use strict;
use warnings;
use Log::Log4perl qw(get_logger);

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
  if ( defined $self->{regfile} ) {
	$self->{registry}->load_all( $self->{regfile} );
  } else {
      $self->registry()->load_registry_from_db(@args);
      $self->registry()->set_disconnect_when_inactive(1);
  }
  print $self->{species}."\n";
  $self->{logger} = get_logger();
  return $self;
}

sub registry {
  my ($self) = @_;
  return $self->{registry};
}

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

__END__

=pod

=head1 NAME

Bio::EnsEMBL::Utils::MetaData::DBAFinder::RegistryDBAFinder

=head1 SYNOPSIS

=head1 DESCRIPTION

implementation using a registry to build a list of DBAs

=head1 SUBROUTINES/METHODS

=head2 new

=head2 get_dbas
Description : Return list of DBAs to work on

=head1 AUTHOR

dstaines

=head1 MAINTAINER

$Author$

=head1 VERSION

$Revision$

=cut
