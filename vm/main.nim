import opcode
import decls
import values
import world
import reader
import eval
import std/tables
import std/streams
import std/os
import std/syncio

let argv = os.commandLineParams()

let input = openFileStream(argv[0], FileMode.fmRead)
try:
    let world = loadWorld input
    
    for typeID, decl in pairs(world.typeDecls):
        let staticMembers = decl.staticMembers
        if staticMembers != nil and staticMembers[].len > 0:
            let fields = new seq[Value]
            newSeq(fields[], staticMembers[].len)
            world.staticFields[decl.id] = fields
        
        let staticInit = decl.staticInit
        if staticInit != nil:
            let state = world.newState(decl)
            let scope = Scope(locals: @[])  

            let result = eval(state, scope, staticInit)
            if result != nil:
                case result.kind
                of rReturn: echo "[Warning]: main method should not return a value"
                of rReturnVoid: discard
                of rThrow:
                    echo "[Runtime Error]: Thrown: " & $result.thrown # TODO
                    for info in result.infos:
                        echo "From: " & info
                of rRethrow: echo "[Runtime Error]: `rethrow` action not caught!"
                of rBreak: echo "[Runtime Error]: `break` action not caught!"
                of rNext: echo "[Runtime Error]: `next` action not caught!"
    
    let state = world.newState(world.typeDecls[world.entrypoint[0]])
    let scope = Scope(locals: @[])

    let result = eval(state, scope, Opcode(kind: oSend_ss, ss_t: state.thisType, ss_id: world.entrypoint[1]))
    if result != nil:
        case result.kind
        of rReturn: echo "[Warning]: main method should not return a value"
        of rReturnVoid: discard
        of rThrow:
            echo "[Runtime Error]: Thrown: " & $result.thrown # TODO
            for info in result.infos:
                echo "From: " & info
        of rRethrow: echo "[Runtime Error]: `rethrow` action not caught!"
        of rBreak: echo "[Runtime Error]: `break` action not caught!"
        of rNext: echo "[Runtime Error]: `next` action not caught!"
        

finally:
    input.close()
