package Locale::Codes;


use strict;
use warnings;
require 5.006;

use Carp;
use if $] >= 5.027007, 'deprecate';
use Locale::Codes::Constants;

our($VERSION);
$VERSION='3.56';

use Exporter qw(import);
our(@EXPORT_OK,%EXPORT_TAGS);
@EXPORT_OK   = @Locale::Codes::Constants::CONSTANTS;
%EXPORT_TAGS = ( 'constants' => [ @EXPORT_OK ] );


our(%Data,%Retired);



sub new {
   my($class,$type,$codeset,$show_errors) = @_;
   my $self         = { 'type'     => '',
                        'codeset'  => '',
                        'err'      => (defined($show_errors) ? $show_errors : 1),
                      };

   bless $self,$class;

   $self->type($type)        if ($type);
   $self->codeset($codeset)  if ($codeset);
   return $self;
}

sub show_errors {
   my($self,$val) = @_;
   $$self{'err'}  = $val;
}

sub type {
   my($self,$type) = @_;

   if (! exists $ALL_CODESETS{$type}) {
      # uncoverable branch false
      carp "ERROR: type: invalid argument: $type\n"  if ($$self{'err'});
      return;
   }

   # uncoverable branch false
   if (! $ALL_CODESETS{$type}{'loaded'}) {
      my $label = $ALL_CODESETS{$type}{'module'};
      eval "require Locale::Codes::${label}_Codes";
      # uncoverable branch true
      if ($@) {
         # uncoverable statement
         croak "ERROR: type: unable to load module: ${label}_Codes\n";
      }
      eval "require Locale::Codes::${label}_Retired";
      # uncoverable branch true
      if ($@) {
         # uncoverable statement
         croak "ERROR: type: unable to load module: ${label}_Retired\n";
      }
      $ALL_CODESETS{$type}{'loaded'} = 1;
   }

   $$self{'type'}    = $type;
   $$self{'codeset'} = $ALL_CODESETS{$type}{'default'};
}

sub codeset {
   my($self,$codeset) = @_;

   my $type           = $$self{'type'};
   if (! exists $ALL_CODESETS{$type}{'codesets'}{$codeset}) {
      # uncoverable branch false
      carp "ERROR: codeset: invalid argument: $codeset\n"  if ($$self{'err'});
   }

   $$self{'codeset'}  = $codeset;
}

sub version {
  # uncoverable subroutine
  # uncoverable statement
  my($self) = @_;
  # uncoverable statement
  return $VERSION;
}


sub _code {
   my($self,$code,$codeset,$no_check_code) = @_;
   $code                    = ''  if (! defined($code));
   $codeset                 = lc($codeset)  if (defined($codeset));

   # uncoverable branch true
   if (! $$self{'type'}) {
      # uncoverable statement
      carp "ERROR: no type set for Locale::Codes object\n"  if ($$self{'err'});
      # uncoverable statement
      return (1);
   }
   my $type = $$self{'type'};
   if ($codeset  &&  ! exists $ALL_CODESETS{$type}{'codesets'}{$codeset}) {
      carp "ERROR: _code: invalid codeset provided: $codeset\n"
        if ($$self{'err'});
      return (1);
   }

   # If no codeset was passed in, return the codeset specified.

   $codeset = $$self{'codeset'}  if (! defined($codeset)  ||  $codeset eq '');
   return (0,'',$codeset)        if ($code eq '');

   # Determine the properties of the codeset

   my($op,@args) = @{ $ALL_CODESETS{$type}{'codesets'}{$codeset} };

   if      ($op eq 'lc') {
      $code = lc($code);
   }

   if ($op eq 'uc') {
      $code = uc($code);
   }

   if ($op eq 'ucfirst') {
      $code = ucfirst(lc($code));
   }

   # uncoverable branch false
   if ($op eq 'numeric') {
      if ($code =~ /^\d+$/) {
         my $l = $args[0];
         $code    = sprintf("%.${l}d", $code);

      } else {
         # uncoverable statement
         carp "ERROR: _code: invalid numeric code: $code\n"  if ($$self{'err'});
         # uncoverable statement
         return (1);
      }
   }

   # Determine if the code is in the codeset.

   if (! $no_check_code  &&
       ! exists $Data{$type}{'code2id'}{$codeset}{$code}  &&
       ! exists $Retired{$type}{$codeset}{'code'}{$code}  &&
       ! exists $Data{$type}{'codealias'}{$codeset}{$code}) {
      carp "ERROR: _code: code not in codeset: $code [$codeset]\n"
        if ($$self{'err'});
      return (1);
   }

   return (0,$code,$codeset);
}


sub code2name {
   my($self,@args)   = @_;
   my $retired       = 0;
   if (@args  &&  defined($args[$#args])  &&  lc($args[$#args]) eq 'retired') {
      pop(@args);
      $retired       = 1;
   }

   # uncoverable branch true
   if (! $$self{'type'}) {
      # uncoverable statement
      carp "ERROR: no type set for Locale::Codes object\n"  if ($$self{'err'});
      # uncoverable statement
      return (1);
   }
   my $type = $$self{'type'};

   my ($err,$code,$codeset) = $self->_code(@args);
   return undef  if ($err  ||  ! $code);

   $code = $Data{$type}{'codealias'}{$codeset}{$code}
     if (exists $Data{$type}{'codealias'}{$codeset}{$code});

   if (exists $Data{$type}{'code2id'}{$codeset}{$code}) {
      my ($id,$i) = @{ $Data{$type}{'code2id'}{$codeset}{$code} };
      my $name    = $Data{$type}{'id2names'}{$id}[$i];
      return $name;

   } elsif ($retired  &&  exists $Retired{$type}{$codeset}{'code'}{$code}) {
      return $Retired{$type}{$codeset}{'code'}{$code};

   } else {
      return undef;
   }
}

sub name2code {
   my($self,$name,@args)   = @_;
   return undef  if (! $name);
   $name                   = lc($name);

   my $retired       = 0;
   if (@args  &&  defined($args[$#args])  &&  lc($args[$#args]) eq 'retired') {
      pop(@args);
      $retired       = 1;
   }

   # uncoverable branch true
   if (! $$self{'type'}) {
      # uncoverable statement
      carp "ERROR: no type set for Locale::Codes object\n"  if ($$self{'err'});
      # uncoverable statement
      return (1);
   }
   my $type = $$self{'type'};

   my ($err,$tmp,$codeset) = $self->_code('',@args);
   return undef  if ($err);

   if (exists $Data{$type}{'alias2id'}{$name}) {
      my $id = $Data{$type}{'alias2id'}{$name}[0];
      if (exists $Data{$type}{'id2code'}{$codeset}{$id}) {
         return $Data{$type}{'id2code'}{$codeset}{$id};
      }

   } elsif ($retired  &&  exists $Retired{$type}{$codeset}{'name'}{$name}) {
      return $Retired{$type}{$codeset}{'name'}{$name}[0];
   }

   return undef;
}

sub code2code {
   my($self,@args) = @_;

   # uncoverable branch true
   if (! $$self{'type'}) {
      # uncoverable statement
      carp "ERROR: no type set for Locale::Codes object\n"  if ($$self{'err'});
      # uncoverable statement
      return (1);
   }
   my $type = $$self{'type'};

   my($code,$codeset1,$codeset2,$err);

   if (@args == 2) {
      ($code,$codeset2)      = @args;
      ($err,$code,$codeset1) = $self->_code($code);
      # uncoverable branch true
      return undef  if ($err);

   } elsif (@args == 3) {
      ($code,$codeset1,$codeset2) = @args;
      ($err,$code)                = $self->_code($code,$codeset1);
      return undef  if ($err);
      ($err)                      = $self->_code('',$codeset2);
      # uncoverable branch true
      return undef  if ($err);
   }

   my $name    = $self->code2name($code,$codeset1);
   my $out     = $self->name2code($name,$codeset2);
   return $out;
}



sub all_codes {
   my($self,@args)   = @_;
   my $retired       = 0;
   if (@args  &&  defined($args[$#args])  &&  lc($args[$#args]) eq 'retired') {
      pop(@args);
      $retired       = 1;
   }

   # uncoverable branch true
   if (! $$self{'type'}) {
      # uncoverable statement
      carp "ERROR: no type set for Locale::Codes object\n"  if ($$self{'err'});
      # uncoverable statement
      return (1);
   }
   my $type = $$self{'type'};

   my ($err,$tmp,$codeset) = $self->_code('',@args);
   return ()  if ($err);

   my @codes = keys %{ $Data{$type}{'code2id'}{$codeset} };
   push(@codes,keys %{ $Retired{$type}{$codeset}{'code'} })  if ($retired);
   return (sort @codes);
}

sub all_names {
   my($self,@args)   = @_;
   my $retired       = 0;
   if (@args  &&  defined($args[$#args])  &&  lc($args[$#args]) eq 'retired') {
      pop(@args);
      $retired       = 1;
   }

   # uncoverable branch true
   if (! $$self{'type'}) {
      # uncoverable statement
      carp "ERROR: no type set for Locale::Codes object\n"  if ($$self{'err'});
      # uncoverable statement
      return (1);
   }
   my $type = $$self{'type'};

   my ($err,$tmp,$codeset) = $self->_code('',@args);
   return ()  if ($err);

   my @codes = $self->all_codes($codeset);
   my @names;

   foreach my $code (@codes) {
      my($id,$i) = @{ $Data{$type}{'code2id'}{$codeset}{$code} };
      my $name   = $Data{$type}{'id2names'}{$id}[$i];
      push(@names,$name);
   }
   if ($retired) {
      foreach my $lc (keys %{ $Retired{$type}{$codeset}{'name'} }) {
         my $name = $Retired{$type}{$codeset}{'name'}{$lc}[1];
         push @names,$name;
      }
   }
   return (sort @names);
}


sub rename_code {
   my($self,$code,$new_name,$codeset) = @_;

   # uncoverable branch true
   if (! $$self{'type'}) {
      # uncoverable statement
      carp "ERROR: no type set for Locale::Codes object\n"  if ($$self{'err'});
      # uncoverable statement
      return 0;
   }
   my $type = $$self{'type'};

   # Make sure $code/$codeset are both valid

   my($err,$c,$cs) = $self->_code($code,$codeset);
   if ($err) {
      carp "ERROR: rename: Unknown code/codeset: $code [$codeset]\n"
        if ($$self{'err'});
      return 0;
   }
   ($code,$codeset) = ($c,$cs);

   # Cases:
   #   1. Renaming to a name which exists with a different ID
   #      Error
   #
   #   2. Renaming to a name which exists with the same ID
   #      Just change code2id (I value)
   #
   #   3. Renaming to a new name
   #      Create a new alias
   #      Change code2id (I value)

   my $id = $Data{$type}{'code2id'}{$codeset}{$code}[0];

   if (exists $Data{$type}{'alias2id'}{lc($new_name)}) {
      # Existing name (case 1 and 2)

      my ($new_id,$i) = @{ $Data{$type}{'alias2id'}{lc($new_name)} };
      if ($new_id != $id) {
         # Case 1
         carp "ERROR: rename: rename to an existing name not allowed\n"
           if ($$self{'err'});
         return 0;
      }

      # Case 2

      $Data{$type}{'code2id'}{$codeset}{$code}[1] = $i;

   } else {

      # Case 3

      push @{ $Data{$type}{'id2names'}{$id} },$new_name;
      my $i = $#{ $Data{$type}{'id2names'}{$id} };
      $Data{$type}{'alias2id'}{lc($new_name)} = [ $id,$i ];
      $Data{$type}{'code2id'}{$codeset}{$code}[1] = $i;
   }

   return 1;
}


sub add_code {
   my($self,$code,$name,$codeset) = @_;

   # uncoverable branch true
   if (! $$self{'type'}) {
      # uncoverable statement
      carp "ERROR: no type set for Locale::Codes object\n"  if ($$self{'err'});
      # uncoverable statement
      return 0;
   }
   my $type = $$self{'type'};

   # Make sure that $codeset is valid.

   my($err,$c,$cs) = $self->_code($code,$codeset,1);
   if ($err) {
      carp "ERROR: rename: Unknown codeset: $codeset\n"
        if ($$self{'err'});
      return 0;
   }
  ($code,$codeset) = ($c,$cs);

   # Check that $code is unused.

   if (exists $Data{$type}{'code2id'}{$codeset}{$code}  ||
       exists $Data{$type}{'codealias'}{$codeset}{$code}) {
      carp "add_code: code already in use: $code\n"  if ($$self{'err'});
      return 0;
   }

   # Check to see that $name is unused in this code set.  If it is
   # used (but not in this code set), we'll use that ID.  Otherwise,
   # we'll need to get the next available ID.

   my ($id,$i);
   if (exists $Data{$type}{'alias2id'}{lc($name)}) {
      ($id,$i) = @{ $Data{$type}{'alias2id'}{lc($name)} };
      if (exists $Data{$type}{'id2code'}{$codeset}{$id}) {
         carp "add_code: name already in use: $name\n"  if ($$self{'err'});
         return 0;
      }

   } else {
      $id = $Data{$type}{'id'}++;
      $i  = 0;
      $Data{$type}{'alias2id'}{lc($name)} = [ $id,$i ];
      $Data{$type}{'id2names'}{$id}       = [ $name ];
   }

   # Add the new code

   $Data{$type}{'code2id'}{$codeset}{$code} = [ $id,$i ];
   $Data{$type}{'id2code'}{$codeset}{$id}   = $code;

   return 1;
}


sub delete_code {
   my($self,$code,$codeset) = @_;

   # uncoverable branch true
   if (! $$self{'type'}) {
      # uncoverable statement
      carp "ERROR: no type set for Locale::Codes object\n"  if ($$self{'err'});
      # uncoverable statement
      return 0;
   }
   my $type = $$self{'type'};

   # Make sure $code/$codeset are both valid

   my($err,$c,$cs) = $self->_code($code,$codeset);
   # uncoverable branch true
   if ($err) {
      # uncoverable statement
      carp "ERROR: rename: Unknown code/codeset: $code [$codeset]\n"
        if ($$self{'err'});
      # uncoverable statement
      return 0;
   }
   ($code,$codeset) = ($c,$cs);

   # Delete the code

   my $id = $Data{$type}{'code2id'}{$codeset}{$code}[0];
   delete $Data{$type}{'code2id'}{$codeset}{$code};
   delete $Data{$type}{'id2code'}{$codeset}{$id};

   # Delete any aliases that are linked to this code

   foreach my $alias (keys %{ $Data{$type}{'codealias'}{$codeset} }) {
      next  if ($Data{$type}{'codealias'}{$codeset}{$alias} ne $code);
      delete $Data{$type}{'codealias'}{$codeset}{$alias};
   }

   # If this ID is not used in any other codeset, delete it completely.

   foreach my $c (keys %{ $Data{$type}{'id2code'} }) {
      return 1  if (exists $Data{$type}{'id2code'}{$c}{$id});
   }

   my @names = @{ $Data{$type}{'id2names'}{$id} };
   delete $Data{$type}{'id2names'}{$id};

   foreach my $name (@names) {
      delete $Data{$type}{'alias2id'}{lc($name)};
   }

   return 1;
}


sub add_alias {
   my($self,$name,$new_name) = @_;

   # uncoverable branch true
   if (! $$self{'type'}) {
      # uncoverable statement
      carp "ERROR: no type set for Locale::Codes object\n"  if ($$self{'err'});
      # uncoverable statement
      return 0;
   }
   my $type = $$self{'type'};

   # Check that $name is used and $new_name is new.

   my($id);
   if (exists $Data{$type}{'alias2id'}{lc($name)}) {
      $id = $Data{$type}{'alias2id'}{lc($name)}[0];
   } else {
      carp "add_alias: name does not exist: $name\n"  if ($$self{'err'});
      return 0;
   }

   if (exists $Data{$type}{'alias2id'}{lc($new_name)}) {
      carp "add_alias: alias already in use: $new_name\n"  if ($$self{'err'});
      return 0;
   }

   # Add the new alias

   push @{ $Data{$type}{'id2names'}{$id} },$new_name;
   my $i = $#{ $Data{$type}{'id2names'}{$id} };
   $Data{$type}{'alias2id'}{lc($new_name)} = [ $id,$i ];

   return 1;
}


sub delete_alias {
   my($self,$name) = @_;

   # uncoverable branch true
   if (! $$self{'type'}) {
      # uncoverable statement
      carp "ERROR: no type set for Locale::Codes object\n"  if ($$self{'err'});
      # uncoverable statement
      return 0;
   }
   my $type = $$self{'type'};

   # Check that $name is used.

   my($id,$i);
   if (exists $Data{$type}{'alias2id'}{lc($name)}) {
      ($id,$i) = @{ $Data{$type}{'alias2id'}{lc($name)} };
   } else {
      carp "delete_alias: name does not exist: $name\n"  if ($$self{'err'});
      return 0;
   }

   my $n = $#{ $Data{$type}{'id2names'}{$id} } + 1;
   if ($n == 1) {
      carp "delete_alias: only one name defined (use delete_code instead)\n"
        if ($$self{'err'});
      return 0;
   }

   # Delete the alias.

   splice (@{ $Data{$type}{'id2names'}{$id} },$i,1);
   delete $Data{$type}{'alias2id'}{lc($name)};

   # Every element that refers to this ID:
   #   Ignore     if I < $i
   #   Set to 0   if I = $i
   #   Decrement  if I > $i

   foreach my $codeset (keys %{ $Data{$type}{'code2id'} }) {
      foreach my $code (keys %{ $Data{$type}{'code2id'}{$codeset} }) {
         my($jd,$j) = @{ $Data{$type}{'code2id'}{$codeset}{$code} };
         next  if ($jd ne $id  ||
                   $j < $i);
         if ($i == $j) {
            $Data{$type}{'code2id'}{$codeset}{$code}[1] = 0;
         } else {
            $Data{$type}{'code2id'}{$codeset}{$code}[1]--;
         }
      }
   }

   return 1;
}


sub replace_code {
   my($self,$code,$new_code,$codeset) = @_;

   # uncoverable branch true
   if (! $$self{'type'}) {
      # uncoverable statement
      carp "ERROR: no type set for Locale::Codes object\n"  if ($$self{'err'});
      # uncoverable statement
      return 0;
   }
   my $type = $$self{'type'};

   # Make sure $code/$codeset are both valid (and that $new_code is the
   # correct format)

   my($err,$c,$cs) = $self->_code($code,$codeset);
   if ($err) {
      carp "ERROR: rename_code: Unknown code/codeset: $code [$codeset]\n"
        if ($$self{'err'});
      return 0;
   }
   ($code,$codeset) = ($c,$cs);

   ($err,$new_code,$codeset) = $self->_code($new_code,$codeset,1);

   # Cases:
   #   1. Renaming code to an existing alias of this code:
   #      Make the alias real and the code an alias
   #
   #   2. Renaming code to some other existing alias:
   #      Error
   #
   #   3. Renaming code to some other code:
   #      Error (
   #
   #   4. Renaming code to a new code:
   #      Make code into an alias
   #      Replace code with new_code.

   if (exists $Data{$type}{'codealias'}{$codeset}{$new_code}) {
      # Cases 1 and 2
      if ($Data{$type}{'codealias'}{$codeset}{$new_code} eq $code) {
         # Case 1

         delete $Data{$type}{'codealias'}{$codeset}{$new_code};

      } else {
         # Case 2
         carp "rename_code: new code already in use: $new_code\n"
           if ($$self{'err'});
         return 0;
      }

   } elsif (exists $Data{$type}{'code2id'}{$codeset}{$new_code}) {
      # Case 3
      carp "rename_code: new code already in use: $new_code\n"
        if ($$self{'err'});
      return 0;
   }

   # Cases 1 and 4

   $Data{$type}{'codealias'}{$codeset}{$code} = $new_code;

   my $id = $Data{$type}{'code2id'}{$codeset}{$code}[0];
   $Data{$type}{'code2id'}{$codeset}{$new_code} =
     $Data{$type}{'code2id'}{$codeset}{$code};
   delete $Data{$type}{'code2id'}{$codeset}{$code};

   $Data{$type}{'id2code'}{$codeset}{$id} = $new_code;

   return 1;
}


sub add_code_alias {
   my($self,$code,$new_code,$codeset) = @_;

   # uncoverable branch true
   if (! $$self{'type'}) {
      # uncoverable statement
      carp "ERROR: no type set for Locale::Codes object\n"  if ($$self{'err'});
      # uncoverable statement
      return 0;
   }
   my $type = $$self{'type'};

   # Make sure $code/$codeset are both valid and that the new code is
   # properly formatted.

   my($err,$c,$cs) = $self->_code($code,$codeset);
   if ($err) {
      carp "ERROR: add_code_alias: Unknown code/codeset: $code [$codeset]\n"
        if ($$self{'err'});
      return 0;
   }
   ($code,$codeset) = ($c,$cs);

   ($err,$new_code,$cs) = $self->_code($new_code,$codeset,1);

   # Check that $new_code does not exist.

   if (exists $Data{$type}{'code2id'}{$codeset}{$new_code}  ||
       exists $Data{$type}{'codealias'}{$codeset}{$new_code}) {
      # uncoverable branch true
      carp "add_code_alias: code already in use: $new_code\n"  if ($$self{'err'});
      return 0;
   }

   # Add the alias

   $Data{$type}{'codealias'}{$codeset}{$new_code} = $code;

   return 1;
}


sub delete_code_alias {
   my($self,$code,$codeset) = @_;

   # uncoverable branch true
   if (! $$self{'type'}) {
      # uncoverable statement
      carp "ERROR: no type set for Locale::Codes object\n"  if ($$self{'err'});
      # uncoverable statement
      return 0;
   }
   my $type = $$self{'type'};

   # Make sure $code/$codeset are both valid

   my($err,$c,$cs) = $self->_code($code,$codeset);
   if ($err) {
      # uncoverable branch true
      carp "ERROR: rename: Unknown code/codeset: $code [$codeset]\n"
        if ($$self{'err'});
      return 0;
   }
   ($code,$codeset) = ($c,$cs);

   # Check that $code exists in the codeset as an alias.

   if (! exists $Data{$type}{'codealias'}{$codeset}{$code}) {
      # uncoverable branch true
      carp "delete_code_alias(): no alias defined: $code\n"  if ($$self{'err'});
      return 0;
   }

   # Delete the alias

   delete $Data{$type}{'codealias'}{$codeset}{$code};

   return 1;
}

1;
