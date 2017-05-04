scope Bomb

    globals
        private constant integer SPELL_ID = 'AH62'
        private constant string MODEL = "Abilities\\Weapons\\MakuraMissile\\MakuraMissile.mdl"
        private constant string SFX_HIT = "Models\\Effects\\BombExplosion.mdx"
        private constant real SPEED = 800.0
        private constant player NEUTRAL = Player(14)
    endglobals

    private function DamageDealt takes integer level returns real
        if level == 11 then
            return 1200.0
        endif
        return 60.0*level
    endfunction

    private function Radius takes integer level returns real
        return 0.0*level + 350.0
    endfunction

    private function TargetFilter takes unit u, player p returns boolean
        return UnitAlive(u) and IsUnitEnemy(u, p) and not IsUnitType(u, UNIT_TYPE_STRUCTURE) and not IsUnitType(u, UNIT_TYPE_MAGIC_IMMUNE)
    endfunction

    struct Bomb extends array

        private unit caster
        private player owner
        private integer lvl
        private Missile m

        private static group g

        private method destroy takes nothing returns nothing
            call this.m.destroy()
            set this.caster = null
            set this.owner = null
        endmethod

        private static method onHit takes nothing returns nothing
            local thistype this = Missile.getHit()
            local real radius = Radius(this.lvl)
            local unit u
            call GroupUnitsInArea(thistype.g, this.m.x, this.m.y, Radius(this.lvl))
            call DestroyEffect(AddSpecialEffect(SFX_HIT, this.m.x, this.m.y))
            loop
                set u = FirstOfGroup(thistype.g)
                exitwhen u == null
                call GroupRemoveUnit(thistype.g, u)
                if TargetFilter(u, this.owner) then

                endif
            endloop
            call this.destroy()
        endmethod

        private static method onCast takes nothing returns nothing
            local thistype this = thistype(Missile.create())
            local real x = GetSpellTargetX()
            local real y = GetSpellTargetY()
            set this.caster = GetTriggerUnit()
            set this.owner = GetTriggerPlayer()
            set this.lvl = GetUnitAbilityLevel(this.caster, SPELL_ID)
            set this.m = Missile(this)
            set this.m.sourceUnit = this.caster
            call this.m.targetXYZ(x, y, GetPointZ(x, y) + 5.0)
            set this.m.speed = SPEED
            set this.m.model = MODEL
            set this.m.scale = 1.5
            set this.m.autohide = true
            set this.m.projectile = true
            set this.m.arc = 2.5
            call this.m.registerOnHit(function thistype.onHit)
            call this.m.launch()
            call SystemMsg.create(GetUnitName(GetTriggerUnit()) + " cast thistype")
        endmethod

        static method init takes nothing returns nothing
            call SystemTest.start("Initializing thistype: ")
            set thistype.g = CreateGroup()
            call RegisterSpellEffectEvent(SPELL_ID, function thistype.onCast)
            call SystemTest.end()
        endmethod

    endstruct
endscope