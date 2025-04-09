# carbon-credits
These smart contracts provide a comprehensive system for carbon credit tokenization, issuance, trading, and retirement. Here's an explanation of each component:

## CarbonCredits Contract

>Manages the core functionality using `ERC-1155` multi-token standard

>Implements role-based access control for issuers and verifiers

>Allows project creation, verification, and credit issuance

>Supports carbon credit retirement with proper tracking

>Maintains detailed metadata for projects and credit batches

#### Vintage

- The vintage represents the year in which the carbon reduction or sequestration actually occurred
*For example, if a forest conservation project prevented carbon emissions in 2025, the carbon credits would have a 2025 vintage*

- This is important because carbon credits from different years may have different values in the market (newer vintages often trade at premium prices)

- Buyers sometimes specifically seek credits from certain years based on their offsetting goals or reporting requirements

- In the contract, it's stored as a uint256 value representing the year (e.g., 2025)

#### Serial Number

- The serialNumber provides a unique identifier for each batch of credits within a project
- It helps prevent double-counting and enables full traceability of credits
- This is similar to how traditional carbon registries assign unique serial numbers to each credit issuance
- The serial number might follow a specific format defined by carbon standards (like Verra or Gold Standard)
- In the contract, it's stored as a uint256 but could represent a numeric portion of a more complex identification system

**Together, these variables ensure that each carbon credit batch has a clear provenance and can be tracked throughout its lifecycle from issuance to retirement. This traceability is crucial for maintaining the integrity of the carbon market and preventing issues like double-counting of emissions reductions.**

## CarbonCreditMarketplace Contract

>Provides a marketplace for trading carbon credits

>Allows sellers to list credits for sale at specified prices

>Enables buyers to purchase credits directly

>Handles payment transfers and credit ownership updates


## CarbonCreditRegistry Contract

>Records certifications and validations for carbon projects

>Links to third-party certification standards

>Maintains an auditable history of project credentials



### Key features of this system:

**Traceability:** Each credit batch is linked to a specific project with vintage year and serial numbers<br>
**Transparent retirement:** Credits can be permanently retired with full transaction history<br>
**Verification workflow:** Projects must be verified before credits can be issued<br>
**Flexible metadata:** Rich metadata support for project details and certifications<br>
**Role-based security:** Different permissions for project owners, verifiers, and issuers<br>

### To deploy this system

1. Deploy the CarbonCredits contract first
2. Use the CarbonCredits contract address to deploy the Marketplace and Registry
3. Grant appropriate roles to authorized participants
