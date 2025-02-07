scope StoneVision

    globals
        private constant integer SPELL_ID = 'A631'
        private constant string SFX_TARGET = "Models\\Effects\\StoneVisionTarget.mdx"
        private constant real NODE_RADIUS = 300
        private constant real TIMEOUT = 0.05
    endglobals

    private function Radius takes integer level returns real
        if level == 11 then
            return GLOBAL_SIGHT
        endif
        return 1500.0*level
    endfunction

    private function Duration takes integer level returns real
        return 15.00 + 0.0*level
    endfunction

    private function TargetFilter takes unit u, player owner returns boolean
        return UnitAlive(u) and IsUnitEnemy(u, owner) and IsUnitType(u, UNIT_TYPE_STRUCTURE)
    endfunction

    private struct SightSource

        readonly unit u
        readonly unit target
        private effect sfx

        readonly thistype next
        readonly thistype prev

        method destroy takes nothing returns nothing
            set this.prev.next = this.next
            set this.next.prev = this.prev
            if this.sfx != null then
                call DestroyEffect(this.sfx)
            endif
            if this.u != null then
                call UnitClearBonus(this.u, BONUS_SIGHT_RANGE)
                call RecycleDummy(this.u)
                set this.u = null
            endif
            set this.target = null
            call this.deallocate()
        endmethod

        static method create takes thistype head, unit target, player owner returns thistype
            local thistype this = thistype.allocate()
            local string s = SFX_TARGET
            set this.target = target
            set this.u = GetRecycledDummyAnyAngle(GetUnitX(target), GetUnitY(target), 0)
            call PauseUnit(this.u, false)
            call SetUnitOwner(this.u, owner, false)
            call UnitSetBonus(this.u, BONUS_SIGHT_RANGE, R2I(NODE_RADIUS))
            if IsPlayerEnemy(owner, GetLocalPlayer()) then
                set s = ""
            endif
            set this.sfx = AddSpecialEffectTarget(s, target, "overhead")
            set this.next = head.next
            set this.prev = head
            set this.next.prev = this
            set this.prev.next = this
            return this
        endmethod

        static method head takes nothing returns thistype
            local thistype this = thistype.allocate()
            set this.next = this
            set this.prev = this
            return this
        endmethod

    endstruct

    private struct SpellBuff extends Buff

        public SightSource ss
        public real radius
        private player owner
        private group visible

        private static group g

        private static constant integer RAWCODE = 'D631'
        private static constant integer DISPEL_TYPE = BUFF_POSITIVE
        private static constant integer STACK_TYPE = BUFF_STACK_NONE

        method onRemove takes nothing returns nothing
            local SightSource sight = this.ss.next
            call this.pop()
            if this.ss > 0 then
                //Destroy all SightSource
                loop
                    exitwhen sight == this.ss
                    call sight.destroy()
                    set sight = sight.next
                endloop
                call this.ss.destroy()
                set this.ss = 0
            endif
            call ReleaseGroup(this.visible)
            set this.visible = null
            set this.owner = null
        endmethod

        private static method onPeriod takes nothing returns nothing
            local thistype this = thistype(0).next
            local unit u
            local SightSource ss
            local boolean b
            loop
                exitwhen this == 0
                if this.ss > 0 then
                    call GroupUnitsInArea(thistype.g, GetUnitX(this.target), GetUnitY(this.target), this.radius)
                    set b = this.owner != GetOwningPlayer(this.target)
                    if b then
                        set this.owner = GetOwningPlayer(this.target)
                    endif
                    loop
                        set u = FirstOfGroup(thistype.g)
                        exitwhen u == null
                        call GroupRemoveUnit(thistype.g, u)
                        if not IsUnitInGroup(u, this.visible) and TargetFilter(u, this.owner) then
                            call GroupAddUnit(this.visible, u)
                            call SightSource.create(this.ss, u, this.owner)
                        endif
                    endloop
                    //Update SightSources
                    set ss = this.ss.next
                    loop
                        exitwhen ss == this.ss
                        if IsUnitInRange(this.target, ss.target, this.radius) and TargetFilter(ss.target, this.owner) then
                            call SetUnitX(ss.u, GetUnitX(ss.target))
                            call SetUnitY(ss.u, GetUnitY(ss.target))
                            if b then
                                call SetUnitOwner(ss.u, this.owner, false)
                            endif
                        else
                            call GroupRemoveUnit(this.visible, ss.target)
                            call ss.destroy()
                        endif
                        set ss = ss.next
                    endloop
                endif
                set this = this.next
            endloop
        endmethod

        implement List

        method onApply takes nothing returns nothing
            set this.owner = GetOwningPlayer(this.target)
            set this.visible = NewGroup()
            call this.push(TIMEOUT)
        endmethod

        private static method init takes nothing returns nothing
            call PreloadSpell(thistype.RAWCODE)
            set thistype.g = CreateGroup()
        endmethod

        implement BuffApply
    endstruct

    struct StoneVision extends array

        private static method onCast takes nothing returns nothing
            local unit u = GetTriggerUnit()
            local integer lvl = GetUnitAbilityLevel(u, SPELL_ID)
            local SpellBuff b = SpellBuff.add(u, u)
            set b.duration = Duration(lvl)
            set b.radius = Radius(lvl)
            set b.ss = SightSource.head()
            set u = null
            call SystemMsg.create(GetUnitName(GetTriggerUnit()) + " cast thistype")
        endmethod

        static method init takes nothing returns nothing
            call SystemTest.start("Initializing thistype: ")
            call RegisterSpellEffectEvent(SPELL_ID, function thistype.onCast)
            call SpellBuff.initialize()
            call SystemTest.end()
        endmethod

    endstruct

endscope