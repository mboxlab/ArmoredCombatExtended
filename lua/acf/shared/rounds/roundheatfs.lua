
AddCSLuaFile()

ACF.AmmoBlacklist.HEATFS =  { "AC", "SA","C","MG", "Al","HMG" ,"RAC", "SC","ATR" , "MO" , "RM", "SL", "GL", "HW", "SC", "BOMB" , "GBU", "ASM", "AAM", "SAM", "UAR", "POD", "FFAR", "ATGM", "ARTY", "ECM", "FGL"}

local Round = {}

Round.type = "Ammo" --Tells the spawn menu what entity to spawn
Round.name = "(HEAT-FS) "..ACFTranslation.ShellHEATFS[1] --Human readable name
Round.model = "models/munitions/round_100mm_mortar_shot.mdl" --Shell flight model
Round.desc = ACFTranslation.ShellHEATFS[2]
Round.netid = 18 --Unique ammotype ID for network transmission

function Round.create( Gun, BulletData )
	
	ACF_CreateBullet( BulletData )
	
end

function Round.ConeCalc( ConeAngle, Radius, Length )
	
	local ConeLength = math.tan(math.rad(ConeAngle))*Radius
	local ConeAera = 3.1416 * Radius * (Radius^2 + ConeLength^2)^0.5
	local ConeVol = (3.1416 * Radius^2 * ConeLength)/3

	return ConeLength, ConeAera, ConeVol
	
end

-- Function to convert the player's slider data into the complete round data
function Round.convert( Crate, PlayerData )
	
	local Data = {}
	local ServerData = {}
	local GUIData = {}
	
	if not PlayerData.PropLength then PlayerData.PropLength = 0 end
	if not PlayerData.ProjLength then PlayerData.ProjLength = 0 end
	PlayerData.Data5 = math.max(PlayerData.Data5 or 0, 0)
	if not PlayerData.Data6 then PlayerData.Data6 = 0 end
	if not PlayerData.Data7 then PlayerData.Data7 = 0 end
	if not PlayerData.Data10 then PlayerData.Data10 = 0 end
	
	PlayerData, Data, ServerData, GUIData = ACF_RoundBaseGunpowder( PlayerData, Data, ServerData, GUIData )

	local ConeThick = Data.Caliber/50
	local ConeLength = 0
	local ConeAera = 0
	local AirVol = 0
	ConeLength, ConeAera, AirVol = Round.ConeCalc( PlayerData.Data6, Data.Caliber/2, PlayerData.ProjLength )
	Data.ProjMass = math.max(GUIData.ProjVolume-PlayerData.Data5,0)*7.9/1000 + math.min(PlayerData.Data5,GUIData.ProjVolume)*ACF.HEDensity/1000 + ConeAera*ConeThick*7.9/1000 --Volume of the projectile as a cylinder - Volume of the filler - Volume of the crush cone * density of steel + Volume of the filler * density of TNT + Aera of the cone * thickness * density of steel
	Data.MuzzleVel = ACF_MuzzleVelocity( Data.PropMass, Data.ProjMass, Data.Caliber )
	local Energy = ACF_Kinetic( Data.MuzzleVel*39.37 , Data.ProjMass, Data.LimitVel )
	
	local MaxVol = 0
	local MaxLength = 0
	local MaxRadius = 0
	MaxVol, MaxLength, MaxRadius = ACF_RoundShellCapacity( Energy.Momentum, Data.FrAera, Data.Caliber, Data.ProjLength )
		
	GUIData.MinConeAng = 0
	GUIData.MaxConeAng = math.deg( math.atan((Data.ProjLength - ConeThick )/(Data.Caliber/2)) )
	GUIData.ConeAng = math.Clamp(PlayerData.Data6*1, GUIData.MinConeAng, GUIData.MaxConeAng)
	ConeLength, ConeAera, AirVol = Round.ConeCalc( GUIData.ConeAng, Data.Caliber/2, Data.ProjLength )
	local ConeVol = ConeAera * ConeThick
		
	GUIData.MinFillerVol = 0
	GUIData.MaxFillerVol = math.max(MaxVol -  AirVol - ConeVol,GUIData.MinFillerVol)*0.95
	GUIData.FillerVol = math.Clamp(PlayerData.Data5,GUIData.MinFillerVol,GUIData.MaxFillerVol)
	
	Data.FillerMass = GUIData.FillerVol * ACF.HEDensity/1450
	Data.BoomFillerMass = Data.FillerMass / 3 --manually update function "pierceeffect" with the divisor
	Data.ProjMass = math.max(GUIData.ProjVolume-GUIData.FillerVol- AirVol-ConeVol,0)*7.9/1000 + Data.FillerMass + ConeVol*7.9/1000
	Data.MuzzleVel = ACF_MuzzleVelocity( Data.PropMass, Data.ProjMass, Data.Caliber )
	local Energy = ACF_Kinetic( Data.MuzzleVel*39.37 , Data.ProjMass, Data.LimitVel )
	
	--Let's calculate the actual HEAT slug
	Data.SlugMass = ConeVol*7.9/1000
	local Rad = math.rad(GUIData.ConeAng/2)
	Data.SlugCaliber =  Data.Caliber - Data.Caliber * (math.sin(Rad)*0.5+math.cos(Rad)*1.5)/2
	Data.SlugMV = 1.3*( Data.FillerMass/2 * ACF.HEPower * math.sin(math.rad(10+GUIData.ConeAng)/2) /Data.SlugMass)^ACF.HEATMVScale --keep fillermass/2 so that penetrator stays the same
	Data.SlugMass = Data.SlugMass*4^2
	Data.SlugMV = Data.SlugMV/4
	
	local SlugFrAera = 3.1416 * (Data.SlugCaliber/2)^2
	Data.SlugPenAera = SlugFrAera^ACF.PenAreaMod
	Data.SlugDragCoef = ((SlugFrAera/10000)/Data.SlugMass)*1500
	Data.SlugRicochet = 	500									--Base ricochet angle (The HEAT slug shouldn't ricochet at all)
	
	Data.CasingMass = Data.ProjMass - Data.FillerMass - ConeVol*7.9/1000

	--Random bullshit left
	Data.ShovePower = 0.1
	Data.PenAera = Data.FrAera^ACF.PenAreaMod
	Data.DragCoef = ((Data.FrAera/10000)/Data.ProjMass)
	Data.LimitVel = 100										--Most efficient penetration speed in m/s
	Data.KETransfert = 0.1									--Kinetic energy transfert to the target for movement purposes
	Data.Ricochet = 60										--Base ricochet angle
	Data.DetonatorAngle = 75
	
	Data.Detonated = false
	Data.NotFirstPen = false
	Data.BoomPower = Data.PropMass + Data.FillerMass

	if SERVER then --Only the crates need this part
		ServerData.Id = PlayerData.Id
		ServerData.Type = PlayerData.Type
		return table.Merge(Data,ServerData)
	end
	
	if CLIENT then --Only the GUI needs this part	
		GUIData = table.Merge(GUIData, Round.getDisplayData(Data))
		return table.Merge(Data, GUIData)
	end
	
end


function Round.getDisplayData(Data)
	local GUIData = {}

	local SlugEnergy = ACF_Kinetic( Data.SlugMV*39.37 , Data.SlugMass, 999999 )
	GUIData.MaxPen = (SlugEnergy.Penetration/Data.SlugPenAera)*ACF.KEtoRHA
	--GUIData.BlastRadius = (Data.FillerMass/2)^0.33*5*10
	GUIData.BlastRadius = (Data.BoomFillerMass)^0.33*8--*39.37
	GUIData.Fragments = math.max(math.floor((Data.BoomFillerMass/Data.CasingMass)*ACF.HEFrag),2)
	GUIData.FragMass = Data.CasingMass/GUIData.Fragments
	GUIData.FragVel = (Data.BoomFillerMass*ACF.HEPower*1000/Data.CasingMass/GUIData.Fragments)^0.5
	
	return GUIData
end


function Round.network( Crate, BulletData )

	Crate:SetNWString( "AmmoType", "HEATFS" )
	Crate:SetNWString( "AmmoID", BulletData.Id )
	Crate:SetNWFloat( "Caliber", BulletData.Caliber )
	Crate:SetNWFloat( "ProjMass", BulletData.ProjMass )
	Crate:SetNWFloat( "FillerMass", BulletData.FillerMass )
	Crate:SetNWFloat( "PropMass", BulletData.PropMass )
	Crate:SetNWFloat( "DragCoef", BulletData.DragCoef )
	Crate:SetNWFloat( "SlugMass", BulletData.SlugMass )
	Crate:SetNWFloat( "SlugCaliber", BulletData.SlugCaliber )
	Crate:SetNWFloat( "SlugDragCoef", BulletData.SlugDragCoef )
	Crate:SetNWFloat( "MuzzleVel", BulletData.MuzzleVel )
	Crate:SetNWFloat( "Tracer", BulletData.Tracer )

end


--local fakeent = {ACF = {Armour = 0}}
--local fakepen = {Penetration = 999999999}
function Round.cratetxt( BulletData, builtFullData )
	
	local DData = Round.getDisplayData(BulletData)
	
	local str = 
	{
		"Muzzle Velocity: ", math.Round(BulletData.MuzzleVel, 1), " m/s\n",
		"Max Penetration: ", math.floor(DData.MaxPen), " mm\n",
		"Blast Radius: ", math.Round(DData.BlastRadius, 1), " m\n",
		"Blast Energy: ", math.floor((BulletData.BoomFillerMass) * ACF.HEPower), " KJ"
	}
	
	return table.concat(str)
	
end

function Round.detonate( Index, Bullet, HitPos, HitNormal )
	
	ACF_HE( HitPos - Bullet.Flight:GetNormalized()*3, HitNormal, Bullet.BoomFillerMass, Bullet.CasingMass, Bullet.Owner, nil, Bullet.Gun )

	Bullet.Detonated = true
	Bullet.InitTime = SysTime()
	Bullet.Pos = HitPos
	Bullet.Flight = Bullet.Flight:GetNormalized() * Bullet.SlugMV * 39.37
	Bullet.FuseLength = 0.1 + 10/(Bullet.Flight:Length()*0.0254)
	Bullet.DragCoef = Bullet.SlugDragCoef
	
	Bullet.ProjMass = Bullet.SlugMass
	Bullet.CannonCaliber = Bullet.Caliber * 2
	Bullet.Caliber = Bullet.SlugCaliber
	Bullet.PenAera = Bullet.SlugPenAera
	Bullet.Ricochet = Bullet.SlugRicochet
	
	local DeltaTime = SysTime() - Bullet.LastThink
	Bullet.StartTrace = Bullet.Pos - Bullet.Flight:GetNormalized()*(math.min(ACF.PhysMaxVel*DeltaTime,Bullet.FlightTime*Bullet.Flight:Length())+25)
	Bullet.NextPos = Bullet.Pos + (Bullet.Flight * ACF.VelScale * DeltaTime)		--Calculates the next shell position
	
end

function Round.propimpact( Index, Bullet, Target, HitNormal, HitPos, Bone )
	
	if ACF_Check( Target ) then
			
		if Bullet.Detonated then
			Bullet.NotFirstPen = true
			
			local Speed = Bullet.Flight:Length() / ACF.VelScale
			local Energy = ACF_Kinetic( Speed , Bullet.ProjMass, 999999 )
			local HitRes = ACF_RoundImpact( Bullet, Speed, Energy, Target, HitPos, HitNormal , Bone )
			
			if HitRes.Overkill > 0 then
				table.insert( Bullet.Filter , Target )					--"Penetrate" (Ingoring the prop for the retry trace)
				ACF_Spall( HitPos , Bullet.Flight , Bullet.Filter , (Energy.Kinetic*(HitRes.Loss)+0.2)*64 , Bullet.CannonCaliber*2 , Target.ACF.Armour , Bullet.Owner , Target.ACF.Material) --Do some spalling
				Bullet.Flight = Bullet.Flight:GetNormalized() * math.sqrt(Energy.Kinetic * (1 - HitRes.Loss) * ((Bullet.NotFirstPen and ACF.HEATPenLayerMul) or 1) * 2000 / Bullet.ProjMass) * 39.37 
				
				return "Penetrated"
			else
				return false
			end
	
		else
			
			local Speed = Bullet.Flight:Length() / ACF.VelScale
			local Energy = ACF_Kinetic( Speed , Bullet.ProjMass - Bullet.FillerMass, Bullet.LimitVel )
			local HitRes = ACF_RoundImpact( Bullet, Speed, Energy, Target, HitPos, HitNormal , Bone )
			
			if HitRes.Ricochet then
				return "Ricochet"
			else
				Round.detonate( Index, Bullet, HitPos, HitNormal )
				return "Penetrated"
			end
			
		end
	else
		table.insert( Bullet.Filter , Target )
		return "Penetrated"
	end
	
	return false
	
end

function Round.worldimpact( Index, Bullet, HitPos, HitNormal )

	if not Bullet.Detonated then	
		Round.detonate( Index, Bullet, HitPos, HitNormal )
		return "Penetrated"
	end
	
	local Energy = ACF_Kinetic( Bullet.Flight:Length() / ACF.VelScale, Bullet.ProjMass, 999999 )
	local HitRes = ACF_PenetrateGround( Bullet, Energy, HitPos, HitNormal )
	if HitRes.Penetrated then
		return "Penetrated"
	--elseif HitRes.Ricochet then  --penetrator won't ricochet
	--	return "Ricochet"
	else
		return false
	end
	
end

function Round.endflight( Index, Bullet, HitPos, HitNormal )
	
	ACF_RemoveBullet( Index )
	
end

function Round.endeffect( Effect, Bullet )
	
	local Impact = EffectData()
		Impact:SetEntity( Bullet.Crate )
		Impact:SetOrigin( Bullet.SimPos )
		Impact:SetNormal( (Bullet.SimFlight):GetNormalized() )
		Impact:SetScale( Bullet.SimFlight:Length() )
		Impact:SetMagnitude( Bullet.RoundMass )
	util.Effect( "ACF_AP_Impact", Impact )
	
end

function Round.pierceeffect( Effect, Bullet )
	
	if Bullet.Detonated then
	
		local Spall = EffectData()
			Spall:SetEntity( Bullet.Crate )
			Spall:SetOrigin( Bullet.SimPos )
			Spall:SetNormal( (Bullet.SimFlight):GetNormalized() )
			Spall:SetScale( Bullet.SimFlight:Length() )
			Spall:SetMagnitude( Bullet.RoundMass )
		util.Effect( "ACF_AP_Penetration", Spall )
	
	else
		
		local Radius = (Bullet.FillerMass/3)^0.33*8*39.37 --fillermass/3 has to be manually set, as this func uses networked data
		local Flash = EffectData()
			Flash:SetOrigin( Bullet.SimPos )
			Flash:SetNormal( Bullet.SimFlight:GetNormalized() )
			Flash:SetRadius( math.max( Radius, 1 ) )
		util.Effect( "ACF_HEAT_Explosion", Flash )
		
		Bullet.Detonated = true
		Effect:SetModel("models/Gibs/wood_gib01e.mdl")
	
	end
	
end

function Round.ricocheteffect( Effect, Bullet )
	
	local Spall = EffectData()
		Spall:SetEntity( Bullet.Gun )
		Spall:SetOrigin( Bullet.SimPos )
		Spall:SetNormal( (Bullet.SimFlight):GetNormalized() )
		Spall:SetScale( Bullet.SimFlight:Length() )
		Spall:SetMagnitude( Bullet.RoundMass )
	util.Effect( "ACF_AP_Ricochet", Spall )
	
end

function Round.guicreate( Panel, Table )

	acfmenupanel:AmmoSelect( ACF.AmmoBlacklist.HEATFS )
	
	acfmenupanel:CPanelText("BonusDisplay", "")
	
	acfmenupanel:CPanelText("Desc", "")	--Description (Name, Desc)
	acfmenupanel:CPanelText("LengthDisplay", "")	--Total round length (Name, Desc)
	
	--Slider (Name, Value, Min, Max, Decimals, Title, Desc)
	acfmenupanel:AmmoSlider("PropLength",0,0,1000,3, "Propellant Length", "")	
	acfmenupanel:AmmoSlider("ProjLength",0,0,1000,3, "Projectile Length", "")	
	acfmenupanel:AmmoSlider("ConeAng",0,0,1000,3, "HEAT Cone Angle", "")
	acfmenupanel:AmmoSlider("FillerVol",0,0,1000,3, "Total HEAT Warhead volume", "")
	
	acfmenupanel:AmmoCheckbox("Tracer", "Tracer", "")			--Tracer checkbox (Name, Title, Desc)
	
	acfmenupanel:CPanelText("VelocityDisplay", "")	--Proj muzzle velocity (Name, Desc)
	acfmenupanel:CPanelText("BlastDisplay", "")	--HE Blast data (Name, Desc)
	acfmenupanel:CPanelText("FragDisplay", "")	--HE Fragmentation data (Name, Desc)
	
	--acfmenupanel:CPanelText("RicoDisplay", "")	--estimated rico chance
	acfmenupanel:CPanelText("SlugDisplay", "")	--HEAT Slug data (Name, Desc)
	
	Round.guiupdate( Panel, Table )
	
end

function Round.guiupdate( Panel, Table )
	
	local PlayerData = {}
		PlayerData.Id = acfmenupanel.AmmoData.Data.id			--AmmoSelect GUI
		PlayerData.Type = "HEATFS"										--Hardcoded, match ACFRoundTypes table index
		PlayerData.PropLength = acfmenupanel.AmmoData.PropLength	--PropLength slider
		PlayerData.ProjLength = acfmenupanel.AmmoData.ProjLength	--ProjLength slider
		PlayerData.Data5 = acfmenupanel.AmmoData.FillerVol
		PlayerData.Data6 = acfmenupanel.AmmoData.ConeAng
		local Tracer = 0
		if acfmenupanel.AmmoData.Tracer then Tracer = 1 end
		PlayerData.Data10 = Tracer				--Tracer
	
	local Data = Round.convert( Panel, PlayerData )
	
	RunConsoleCommand( "acfmenu_data1", acfmenupanel.AmmoData.Data.id )
	RunConsoleCommand( "acfmenu_data2", PlayerData.Type )
	RunConsoleCommand( "acfmenu_data3", Data.PropLength )		--For Gun ammo, Data3 should always be Propellant
	RunConsoleCommand( "acfmenu_data4", Data.ProjLength )
	RunConsoleCommand( "acfmenu_data5", Data.FillerVol )
	RunConsoleCommand( "acfmenu_data6", Data.ConeAng )
	RunConsoleCommand( "acfmenu_data10", Data.Tracer )
	
	local vol = ACF.Weapons.Ammo[acfmenupanel.AmmoData["Id"]].volume
	local Cap, CapMul, RoFMul = ACF_CalcCrateStats( vol, Data.RoundVolume )
	
	acfmenupanel:CPanelText("BonusDisplay", "Crate info: +"..(math.Round((CapMul-1)*100,1)).."% capacity, +"..(math.Round((RoFMul-1)*-100,1)).."% RoF\nContains "..Cap.." rounds")
	
	acfmenupanel:AmmoSlider("PropLength",Data.PropLength,Data.MinPropLength,Data.MaxTotalLength,3, "Propellant Length", "Propellant Mass : "..(math.floor(Data.PropMass*1000)).." g" )	--Propellant Length Slider (Name, Min, Max, Decimals, Title, Desc)
	acfmenupanel:AmmoSlider("ProjLength",Data.ProjLength,Data.MinProjLength,Data.MaxTotalLength,3, "Projectile Length", "Projectile Mass : "..(math.floor(Data.ProjMass*1000)).." g")	--Projectile Length Slider (Name, Min, Max, Decimals, Title, Desc)
	acfmenupanel:AmmoSlider("ConeAng",Data.ConeAng,Data.MinConeAng,Data.MaxConeAng,0, "Crush Cone Angle", "")	--HE Filler Slider (Name, Min, Max, Decimals, Title, Desc)
	acfmenupanel:AmmoSlider("FillerVol",Data.FillerVol,Data.MinFillerVol,Data.MaxFillerVol,3, "HE Filler Volume", "HE Filler Mass : "..(math.floor(Data.FillerMass*1000)).." g")	--HE Filler Slider (Name, Min, Max, Decimals, Title, Desc)
	
	acfmenupanel:AmmoCheckbox("Tracer", "Tracer : "..(math.floor(Data.Tracer*5)/10).."cm\n", "" )			--Tracer checkbox (Name, Title, Desc)

	acfmenupanel:CPanelText("Desc", ACF.RoundTypes[PlayerData.Type].desc)	--Description (Name, Desc)
	acfmenupanel:CPanelText("LengthDisplay", "Round Length : "..(math.floor((Data.PropLength+Data.ProjLength+(math.floor(Data.Tracer*5)/10))*100)/100).."/"..(Data.MaxTotalLength).." cm")	--Total round length (Name, Desc)
	acfmenupanel:CPanelText("VelocityDisplay", "Muzzle Velocity : "..math.floor(Data.MuzzleVel*ACF.VelScale).." m/s")	--Proj muzzle velocity (Name, Desc)	
	acfmenupanel:CPanelText("BlastDisplay", "Blast Radius : "..(math.floor(Data.BlastRadius*100)/100).." m")	--Proj muzzle velocity (Name, Desc)
	acfmenupanel:CPanelText("FragDisplay", "Fragments : "..(Data.Fragments).."\n Average Fragment Weight : "..(math.floor(Data.FragMass*10000)/10).." g \n Average Fragment Velocity : "..math.floor(Data.FragVel).." m/s")	--Proj muzzle penetration (Name, Desc)
	
	--local RicoAngs = ACF_RicoProbability( Data.Ricochet, Data.MuzzleVel*ACF.VelScale )
	--acfmenupanel:CPanelText("RicoDisplay", "Ricochet probability vs impact angle:\n".."    0% @ "..RicoAngs.Min.." degrees\n  50% @ "..RicoAngs.Mean.." degrees\n100% @ "..RicoAngs.Max.." degrees")
		
	acfmenupanel:CPanelText("SlugDisplay", "Penetrator Mass : "..(math.floor(Data.SlugMass*10000)/10).." g \n Penetrator Caliber : "..(math.floor(Data.SlugCaliber*100)/10).." mm \n Penetrator Velocity : "..math.floor(Data.SlugMV).." m/s \n Penetrator Maximum Penetration : "..math.floor(Data.MaxPen).." mm \n")	--Proj muzzle penetration (Name, Desc)
	
end

list.Set( "ACFRoundTypes", "HEATFS", Round )  --Set the round properties
list.Set( "ACFIdRounds", Round.netid, "HEATFS" ) --Index must equal the ID entry in the table above, Data must equal the index of the table above