// SPDX-Licenser-Identifier : MIT 
// Voting.sol

pragma solidity 0.8.9 ; 

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol" ;

contract Voting is Ownable {
// Initialisation de variables
    uint ProposalId = 0; // Donnera un ID à chaque propositions 
    uint winningProposalId = 0 ; // sera l'ID du gagnant
    address _addressWinner ; // permettra de stocker l'address du winner
    
// Structures    
    // Vote
    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint votedProposalId;
    }
    // Proposition 
    struct Proposal {
        string description ;
        uint voteCount ; 
        uint ProposalId; // J'ai rajouté un ProposalId directement ici pour donner un identifiant à chaque vote
    }

// Enumération de l'état d'un Vote 
    enum WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }
/*  On initialise notre enum afin d'autoriser la première phase : le whitelistage
    // On pourrait faire : 
    // WorkflowStatus public CurrentStatus = WorkflowStatus.RegisteringVoters ;
    Mais etant donné que ce sont des actions à répétition, nous allons putôt créer une fonction qui nous le permette
*/ 
    WorkflowStatus public CurrentStatus ;

// Les événements 
    event VoterRegistered(address voterAddress) ; // Vote enregistré
    // Changement de procèdure / d'état 
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus) ;
    event ProposalRegistered(uint proposalId) ; // Enregistrement d'une proposition
    event Voted (address voter, uint proposalId) ; // À voté

// mapping
    mapping (address => bool) Whitelist ;
    mapping (address => bool) Blacklist ;

    mapping (address => Voter) Votes ;
    mapping (address => Proposal) Propositions ;

// ----------------------------------------------------------------------------------------------------------
// ----------------------------------------------------------------------------------------------------------
// Fonction Whitelist et Blacklist
// Seul le déployeur du contrat peut Whitelister ou Blacklister des gens
    function Whitelisted (address _address) public onlyOwner {
        // On whitelist seulement si l'address n'est pas déjà whitelisté ou blacklisté
        require(CurrentStatus == WorkflowStatus.RegisteringVoters, "Sorry, the registration period is over") ;
        require(!Whitelist[_address], "This address is already whitelisted") ;
        require(!Blacklist[_address], "This address is already blacklisted, you can't whitelist it anymore");
        Whitelist[_address] = true ;
        Votes [_address] = (true, false, none) ; // isRegistered passe à true
        emit VoterRegistered(_address) ; // Vote enregistré
    }
 
    function Blacklisted (address _address) public {
        // On balcklist seulement si l'address n'est pas déjà blacklisté
        // Remarque : on peut blacklister une address whitelisté. L'inverse ne fonctionne pas
        require(!Blacklist[_address], "This address is already blacklisted");
        Blacklist [_address] = true ;
    }

/* Un ensemble de fonctions permettant de définir l'état du WorkflowStatus 
    function RegisteringVotersOpen () public { CurrentStatus = WorkflowStatus.RegisteringVoters ; }
    function ProposalsRegistrationOpen () public { CurrentStatus = WorkflowStatus.ProposalsRegistrationStarted ; }
    function ProposalsRegistrationClose () public { CurrentStatus = WorkflowStatus.ProposalsRegistrationEnded ; }
    function VotingSessionOpen () public { CurrentStatus = WorkflowStatus.VotingSessionStarted ; }
    function VotingSessionClose () public { CurrentStatus = WorkflowStatus.VotingSessionEnded ; }
    function VotesTalliedOpen () public { CurrentStatus = WorkflowStatus.VotesTallied ; }
*/  // Ou bien si la personne connait les noms des différents status, on pourrait également écrire comme suit : 
    function CurrentWorkflowStatus (WorkflowStatus newStatus) public {
        emit WorkflowStatusChange(CurrentStatus, newStatus) ;
        CurrentStatus = newStatus ;
    }
    
    // Fonction permettant d'enregistrer les votes et les messages des whitelisté 
    function RegistrationSession (address _address, string memory _message) public {
        require(CurrentStatus == WorkflowStatus.ProposalsRegistrationStarted, "Sorry, the registration session is not open for the moment");
        require(Votes.isRegistered [_address] == true, "Sorry you are not registered") ; // Q : Peut être ne pas mettre _address ici mais plutôt msg.sender ?
        ProposalId += 1; // l'ID de ce vote sera de (ProposalId +1)
        Propositions [_address] = (_message, 0, ProposalId); // 0 car on itinitialise le nombre de vote pour ce message à 0
    }

    // Fonction permettant de voter pour une address
    // On pourrait tout aussi bien voter pour un voteCount, l'ID du vote, car une address c'est long mais je sais pas comment m'y prendre
    function VotingSession (address _address) public {
        require(CurrentStatus == WorkflowStatus.RegisteringVotersOpen, "Sorry, you can not Vote for the moment") ;
        require(Votes.isRegistered [msg.sender] == true, "Sorry you are not registered") ;        
        // Je ne met pas l'address en dessous car l'address désigne la personne pour qui on souhaite voter. 
        // Et c'est le msg.sender qui vote pour cette personne. Son address doit donc être whitelisté.
        require(Votes.isRegistered [msg.sender] == true, "Sorry you are not registered") ;
        Propositions.voteCount [_address] += 1; // La personne déside de voter pour '_address', on lui rajoute donc un point au voteCount
        Votes.hasVoted [msg.sender] = true ;    // l'état de 'a déjà voté' passe a "true"
        Votes.votedProposalId [msg.sender] = Propositions.ProposalId[_address] ; // On indique pour quelle ProposalId le msg.sender à voté
        // Si l'address actuelle a plus de vote que la précédente, on remplace l'ancien gagnant par la nouvelle address
        if (winningProposalId < Propositions.voteCount[_address]) 
            winningProposalId = Propositions.voteCount[_address] ;
            _addressWinner = _address ;
        // Je ne prend en revanche pas en compte ici la possibilité qu'il y ai deux address ou plus avec un même nombres de points
    }  

    // Fonction retournant l'addresse du gagnant, son message ainsi que le nombre de vote qu'il a obtenu. 
    function getWinner () public returns(address, string, uint) {
        require(CurrentStatus == WorkflowStatus.VotesTallied, "Sorry the Process is not yet finished. Please wait.");
        require(Propositions.voteCount[_address]) ;
        return (_addressWinner, Propositions.message[_addressWinner], Propositions.voteCount[_addressWinner]) ;
    }

    // Q : Comment on fait des boucle for pour par exemple parcourir une whitelist afin de trouver le vainqueur ? 
}