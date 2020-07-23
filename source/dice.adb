with Ada.Command_Line;
with Ada.Command_Line.Parsing;
with Ada.Containers.Generic_Constrained_Array_Sort;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Hierarchical_File_Names;
with Ada.Long_Long_Integer_Text_IO;
with Ada.Numerics.Distributions;
with Ada.Numerics.SFMT_19937;
with Ada.Text_IO;
procedure dice is
	package SFMT_19937 renames Ada.Numerics.SFMT_19937;
	procedure Save (Gen : in SFMT_19937.Generator; Name : in String) is
		File : Ada.Text_IO.File_Type;
		State : SFMT_19937.State;
	begin
		SFMT_19937.Save (Gen, State);
		Ada.Text_IO.Create (File, Name => Name);
		Ada.Text_IO.Put_Line (File, SFMT_19937.Id);
		Ada.Text_IO.Put_Line (File, SFMT_19937.Image (State));
		Ada.Text_IO.Close (File);
	end Save;
	procedure Load (Gen : in out SFMT_19937.Generator; Name : in String) is
		File : Ada.Text_IO.File_Type;
		State : SFMT_19937.State;
	begin
		Ada.Text_IO.Open (File, Mode => Ada.Text_IO.In_File, Name => Name);
		if Ada.Text_IO.Get_Line (File) /= SFMT_19937.Id then
			raise Ada.Text_IO.Data_Error;
		end if;
		State := SFMT_19937.Value (Ada.Text_IO.Get_Line (File));
		Ada.Text_IO.Close (File);
		SFMT_19937.Reset (Gen, State);
	end Load;
	package Distributions renames Ada.Numerics.Distributions;
	package Hierarchical_File_Names renames Ada.Hierarchical_File_Names;
	function Default_State_Name return String is
	begin
		return Hierarchical_File_Names.Compose (
			Ada.Environment_Variables.Value ("HOME"),
			".dice");
	end Default_State_Name;
	procedure Help is
		procedure P (Item : in String) renames Ada.Text_IO.Put_Line;
	begin
		Ada.Text_IO.Put ("Usage: ");
		Ada.Text_IO.Put (Ada.Command_Line.Command_Name);
		Ada.Text_IO.Put (" [options] N [K]");
		Ada.Text_IO.New_Line;
		P ("Cast dices with the pseudo random number generator.");
		Ada.Text_IO.New_Line;
		P ("Options: ");
		P ("  -C --combination      Use ""combination without rerepetition"" (nCk)");
		P ("  -h --help             Display this information");
		P ("  -n --dry-run          "
			& "Do not save the the pseudo random number sequence");
		P ("  -P --sequence         Use ""sequence without rerepetition"" (nPk)");
		P ("     --repetition       Cast a dice with N faces K times (default)");
	end Help;
	package Parsing renames Ada.Command_Line.Parsing;
	type Mode_Type is (Repetition, Sequence, Combination);
	subtype Mode_Type_Without_Repetition is
		Mode_Type range Sequence .. Combination;
	Mode : Mode_Type := Repetition;
	Dry_Run : Boolean := False;
	N, K : Long_Long_Integer := 0;
begin
	for I in Parsing.Iterate loop
		if Parsing.Is_Option (I, 'C', "combination") then
			Mode := Combination;
		elsif Parsing.Is_Option (I, 'h', "help") then
			Help;
			return;
		elsif Parsing.Is_Option (I, 'n', "dry-run") then
			Dry_Run := True;
		elsif Parsing.Is_Option (I, 'P', "sequence") then
			Mode := Sequence;
		elsif Parsing.Is_Option (I, "repetition") then
			Mode := Repetition;
		elsif Parsing.Is_Unknown_Option (I) then
			Ada.Text_IO.Set_Output (Ada.Text_IO.Standard_Error.all);
			Ada.Text_IO.Put ("Unknown option: ");
			Ada.Text_IO.Put (Parsing.Name (I));
			Ada.Text_IO.New_Line;
			Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
			return;
		else
			declare
				Argument : constant String := Parsing.Argument (I);
			begin
				if N = 0 then
					N := Long_Long_Integer'Value (Argument);
					if N <= 0 then
						Ada.Text_IO.Set_Output (Ada.Text_IO.Standard_Error.all);
						Ada.Text_IO.Put ("N should be positive.");
						Ada.Text_IO.New_Line;
						Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
						return;
					end if;
				elsif K = 0 then
					K := Long_Long_Integer'Value (Argument);
					if K <= 0 then
						Ada.Text_IO.Set_Output (Ada.Text_IO.Standard_Error.all);
						Ada.Text_IO.Put ("K should be positive.");
						Ada.Text_IO.New_Line;
						Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
						return;
					end if;
				else
					Ada.Text_IO.Set_Output (Ada.Text_IO.Standard_Error.all);
					Ada.Text_IO.Put ("Extra argument: ");
					Ada.Text_IO.Put (Argument);
					Ada.Text_IO.New_Line;
					Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
					return;
				end if;
			end;
		end if;
	end loop;
	if N = 0 then
		Ada.Text_IO.Set_Output (Ada.Text_IO.Standard_Error.all);
		Ada.Text_IO.Put ("Specify N.");
		Ada.Text_IO.New_Line;
		Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
		return;
	end if;
	if K = 0 then
		K := 1;
	end if;
	declare
		State_Name : constant String := Default_State_Name;
		subtype Positive_N is Long_Long_Integer range 1 .. N;
		procedure Put (N : Positive_N) is
		begin
			Ada.Long_Long_Integer_Text_IO.Put (N, Width => 1);
			Ada.Text_IO.New_Line;
		end Put;
		Gen : aliased SFMT_19937.Generator;
	begin
		begin
			Load (Gen, State_Name);
		exception
			when Ada.Text_IO.Data_Error =>
				Ada.Text_IO.Set_Output (Ada.Text_IO.Standard_Error.all);
				Ada.Text_IO.Put ("The broken state file: ");
				Ada.Text_IO.Put (State_Name);
				Ada.Text_IO.New_Line;
				Ada.Text_IO.Set_Output (Ada.Text_IO.Standard_Output.all);
				SFMT_19937.Reset (Gen);
			when Ada.Text_IO.Name_Error =>
				Ada.Text_IO.Set_Output (Ada.Text_IO.Standard_Error.all);
				Ada.Text_IO.Put ("Initialized.");
				if not Dry_Run then
					Ada.Text_IO.Put (" The state file: ");
					Ada.Text_IO.Put (State_Name);
				end if;
				Ada.Text_IO.New_Line;
				Ada.Text_IO.Set_Output (Ada.Text_IO.Standard_Output.all);
				SFMT_19937.Reset (Gen);
		end;
		case Mode is
			when Repetition =>
				for I in 1 .. K loop
					declare
						function Random_N is
							new Distributions.Uniform_Discrete_Random (
								SFMT_19937.Unsigned_64,
								Positive_N,
								SFMT_19937.Generator,
								SFMT_19937.Random_64);
						Item : constant Positive_N := Random_N (Gen);
					begin
						Put (Item);
					end;
				end loop;
			when Mode_Type_Without_Repetition => -- Sequence | Combination
				if N < K then
					Ada.Text_IO.Put ("N < K");
					Ada.Text_IO.New_Line;
					Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
					return;
				else
					declare
						subtype Positive_K is Long_Long_Integer range 1 .. K;
						type Positive_N_Array_K is array (Positive_K) of Positive_N;
						Taken : array (1 .. N) of Boolean := (others => False);
						Result : Positive_N_Array_K;
					begin
						for I in 1 .. K loop
							declare
								M : constant Positive_N := N - (I - 1);
								subtype Positive_M is Positive_N range 1 .. M;
								function Random_M is
									new Distributions.Uniform_Discrete_Random (
										SFMT_19937.Unsigned_64,
										Positive_M,
										SFMT_19937.Generator,
										SFMT_19937.Random_64);
								X : constant Positive_M := Random_M (Gen);
								Item : Positive_N := 1;
							begin
								for J in 1 .. X loop
									while Taken (Item) loop
										Item := Item + 1;
									end loop;
									if J < X then
										Item := Item + 1;
									end if;
								end loop;
								pragma Assert (not Taken (Item));
								Taken (Item) := True;
								Result (I) := Item;
							end;
						end loop;
						case Mode_Type_Without_Repetition (Mode) is
							when Sequence =>
								null;
							when Combination =>
								declare
									procedure Sort is
										new Ada.Containers.Generic_Constrained_Array_Sort (
											Positive_K,
											Positive_N,
											Positive_N_Array_K);
								begin
									Sort (Result);
								end;
						end case;
						for I in 1 .. K loop
							Put (Result (I));
						end loop;
					end;
				end if;
		end case;
		if not Dry_Run then
			Save (Gen, State_Name);
		end if;
	end;
end dice;
