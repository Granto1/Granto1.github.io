(pwd() != @__DIR__) && cd(@__DIR__) # allow starting app from bin/ dir

using ProofConcept
const UserApp = ProofConcept
ProofConcept.main()
