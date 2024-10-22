local PetitionSound = {}

SWEP.PrintName = "Petition"
SWEP.DrawCrosshair = true
SWEP.Author = "MrPPenguin"
SWEP.Contact = ""
SWEP.Purpose = ""
SWEP.Instructions = "Left click to play sound\nRight click to request player to sing your petition"
SWEP.Category = "DarkRP"
 
SWEP.Slot = 1
SWEP.SlotPos = 0
SWEP.Spawnable = true
SWEP.AdminSpawnable = true

SWEP.ViewModel = Model("models/postal/c_petition.mdl")
SWEP.UseHands = true
SWEP.WorldModel = Model("models/postal/clipboard.mdl")
SWEP.SetHoldType = slam

SWEP.Primary.Clipsize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary.Clipsize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

local PetitionSound = {
Sound("petition/petition_1.wav"),
Sound("petition/petition_2.wav"),
Sound("petition/petition_3.wav"),
Sound("petition/petition_4.wav"),
Sound("petition/petition_5.wav"),
Sound("petition/petition_6.wav"),
}

function SWEP:Initialize()
	self:SetHoldType( "slam" )
end

function SWEP:Think()
end

function SWEP:Reload()
end

function SWEP:Deploy()
self.Owner:SetAnimation( PLAYER_IDLE );
self.Weapon:SendWeaponAnim( ACT_VM_IDLE );
end

function SWEP:PrimaryAttack()
self.Owner:SetAnimation( PLAYER_IDLE );
self.Weapon:SendWeaponAnim( ACT_VM_PRIMARYATTACK );
	local PetitionSoundFunc = table.Random(PetitionSound)
	self:EmitSound(PetitionSoundFunc)
end

PlayerSignTimes = PlayerSignTimes or {}
PendingPetitions = PendingPetitions or {}
SWEP.NextSecondaryAttack = 0

if SERVER then
	util.AddNetworkString("SendPendingPetitions")
end

function SWEP:SecondaryAttack()
    if CLIENT then return end
    if self.NextSecondaryAttack > CurTime() then return end
    self.NextSecondaryAttack = CurTime() + 1

    self.Owner:SetAnimation(PLAYER_ATTACK1)
    self.Weapon:SendWeaponAnim(ACT_VM_SECONDARYATTACK)

    local trace = self.Owner:GetEyeTrace()
    if not trace.Entity or not trace.Entity:IsPlayer() then
        self.Owner:ChatPrint("You must look at a player to request their signature!")
        return
    end

    local targetPlayer = trace.Entity
    if targetPlayer:IsPlayer() then

        local lastSignTime = PlayerSignTimes[targetPlayer:SteamID()] and PlayerSignTimes[targetPlayer:SteamID()][self.Owner:SteamID()]
        local timeSinceLastSign = lastSignTime and (CurTime() - lastSignTime) or nil

        if timeSinceLastSign and timeSinceLastSign < 3600 then
            self.Owner:ChatPrint(targetPlayer:Nick() .. " can only sign your petition once every hour!")
            return
        end

        targetPlayer:ChatPrint(self.Owner:Nick() .. " has requested you to sign their petition! Type /signpetition to sign.")
        self.Owner:ChatPrint("Sent a sign request to " .. targetPlayer:Nick())
        PendingPetitions[targetPlayer:SteamID()] = { requester = self.Owner:SteamID() }
        
        net.Start("SendPendingPetitions")
        net.WriteTable(PendingPetitions)
        net.Send(targetPlayer)
    end
end

if CLIENT then
    net.Receive("SendPendingPetitions", function()
        local receivedPetitions = net.ReadTable()
        PendingPetitions = receivedPetitions
    end)
    
    hook.Add("OnPlayerChat", "SignPetitionCommand", function(ply, text)
        if string.lower(text) == "/signpetition" then
            net.Start("SignPetition")
            net.WriteString(ply:SteamID()) -- Send the local player's Steam ID
            net.SendToServer()
            return true -- Stop the message from being printed to chat
        end
    end)
end

-- Define the console command for clearing tables
if SERVER then
    util.AddNetworkString("ClearPetitionData")

    concommand.Add("clear_petition_data", function(ply)
        if ply:IsSuperAdmin() then
            PlayerSignTimes = {}
            PendingPetitions = {}
            ply:ChatPrint("Petition data cleared successfully.")

            -- Notify all clients to clear their local data
            net.Start("ClearPetitionData")
            net.Broadcast()

            print("Petition data cleared by " .. ply:Nick())
        else
            ply:ChatPrint("You do not have permission to use this command.")
        end
    end)

    util.AddNetworkString("SignPetition")

    net.Receive("SignPetition", function(len, ply)
        local playerSteamID = net.ReadString()
        local petitionData = PendingPetitions[playerSteamID]
        local plyr = player.GetBySteamID(playerSteamID)
        if not petitionData or not petitionData.requester then
            return
        end

        local petitionOwnerSteamID = petitionData.requester
        local petitionOwner = player.GetBySteamID(petitionOwnerSteamID)

        if not petitionOwner or not petitionOwner:IsPlayer() then
            plyr:ChatPrint("The player who requested your signature is no longer online.")
            PendingPetitions[plyr:SteamID()] = nil
            return
        end

        local lastSignTime = PlayerSignTimes[plyr:SteamID()] and PlayerSignTimes[plyr:SteamID()][petitionOwner:SteamID()]
        local timeSinceLastSign = lastSignTime and (CurTime() - lastSignTime) or nil

        if timeSinceLastSign and timeSinceLastSign < 3600 then
            plyr:ChatPrint("You can only sign " .. petitionOwner:Nick() .. "'s petition once every hour!")
            return
        end

        -- Record the sign time
        PlayerSignTimes[plyr:SteamID()] = PlayerSignTimes[plyr:SteamID()] or {}
        PlayerSignTimes[plyr:SteamID()][petitionOwner:SteamID()] = CurTime()

        -- Notify both players about the signing
        petitionOwner:ChatPrint(plyr:Nick() .. " has signed your petition!")
        plyr:ChatPrint("You have signed " .. petitionOwner:Nick() .. "'s petition!")

        -- Reward the player
        local rewardAmount = 2500 -- Set the amount of money to reward
        if petitionOwner.addMoney then
            petitionOwner:addMoney(rewardAmount)
            petitionOwner:ChatPrint("You have been rewarded $" .. rewardAmount .. " for your petition being signed.")
        end

        petitionOwner:EmitSound("petition/petition_sign.wav")

        -- Clear the pending petition from the global table
        PendingPetitions[plyr:SteamID()] = nil
    end)
end

if CLIENT then
    net.Receive("ClearPetitionData", function()
        PlayerSignTimes = {}
        PendingPetitions = {}
    end)
end

