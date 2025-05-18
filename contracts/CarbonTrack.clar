;; CarbonTrack - Carbon offset verification and trading platform
;; Projects earn tokens based on verification and impact ratings

;; Error codes
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_INPUT (err u103))
(define-constant ERR_ALREADY_VERIFIED (err u104))
(define-constant ERR_ALREADY_RATED (err u105))
(define-constant ERR_SELF_RATING (err u106))
(define-constant ERR_EMPTY_STRING (err u107))
(define-constant ERR_INVALID_RATING (err u108))
(define-constant ERR_INVALID_PROJECT_ID (err u109))
(define-constant ERR_EMPTY_HASH (err u110))

;; Constants
(define-constant MAX_RATING u5)
(define-constant OFFSET_REWARD u10)
(define-constant IMPACT_REWARD u20)
(define-constant VERIFICATION_REWARD u50)

;; Data maps
(define-map organizations
  { org-id: principal }
  { name: (string-ascii 50), org-type: (string-ascii 20), reputation: uint, tokens: uint, verified: bool }
)

(define-map carbon-projects
  { project-id: uint }
  { 
    owner: principal, 
    description: (string-ascii 500), 
    project-hash: (buff 32),
    timestamp: uint, 
    verified: bool,
    verification-count: uint,
    offset-count: uint,
    impact-rating: uint,
    rating-count: uint
  }
)

(define-map project-verifications
  { project-id: uint, verifier: principal }
  { verified: bool }
)

(define-map carbon-offsets
  { project-id: uint, buyer: principal }
  { offset-amount: uint, offset-date: uint }
)

(define-map impact-ratings
  { project-id: uint, rater: principal }
  { rating: uint }
)

;; Variables
(define-data-var next-project-id uint u1)
(define-data-var action-counter uint u0)

;; Helper functions
(define-private (is-valid-project-id (project-id uint))
  (< project-id (var-get next-project-id))
)

;; Organization functions
(define-public (register-organization (name (string-ascii 50)) (org-type (string-ascii 20)))
  (let ((caller tx-sender))
    ;; Validate name is not empty
    (asserts! (> (len name) u0) ERR_EMPTY_STRING)
    ;; Validate org-type is not empty and valid (project, verifier, buyer)
    (asserts! (or (is-eq org-type "project") (is-eq org-type "verifier") (is-eq org-type "buyer")) ERR_INVALID_INPUT)
    ;; Check if organization already exists
    (asserts! (is-none (map-get? organizations {org-id: caller})) ERR_ALREADY_EXISTS)
    ;; Register organization
    (ok (map-set organizations 
      {org-id: caller} 
      {name: name, org-type: org-type, reputation: u0, tokens: u100, verified: false}))
  )
)

(define-public (update-organization (name (string-ascii 50)) (org-type (string-ascii 20)))
  (let ((caller tx-sender))
    ;; Validate name is not empty
    (asserts! (> (len name) u0) ERR_EMPTY_STRING)
    ;; Validate org-type is not empty and valid (project, verifier, buyer)
    (asserts! (or (is-eq org-type "project") (is-eq org-type "verifier") (is-eq org-type "buyer")) ERR_INVALID_INPUT)
    ;; Check if organization exists
    (asserts! (is-some (map-get? organizations {org-id: caller})) ERR_NOT_FOUND)
    ;; Update organization
    (ok (map-set organizations 
      {org-id: caller} 
      (merge (unwrap! (map-get? organizations {org-id: caller}) ERR_NOT_FOUND)
             {name: name, org-type: org-type})))
  )
)

;; Project functions
(define-public (register-project (description (string-ascii 500)) (project-hash (buff 32)))
  (let ((caller tx-sender)
        (project-id (var-get next-project-id)))
    ;; Validate description is not empty
    (asserts! (> (len description) u0) ERR_EMPTY_STRING)
    ;; Validate project-hash is not empty
    (asserts! (> (len project-hash) u0) ERR_EMPTY_HASH)
    ;; Check if organization exists
    (asserts! (is-some (map-get? organizations {org-id: caller})) ERR_NOT_FOUND)
    ;; Increment action counter
    (var-set action-counter (+ (var-get action-counter) u1))
    
    ;; Create project with validated data
    (map-set carbon-projects 
      {project-id: project-id} 
      { 
        owner: caller, 
        description: description, 
        project-hash: project-hash,
        timestamp: (var-get action-counter), 
        verified: false,
        verification-count: u0,
        offset-count: u0,
        impact-rating: u0,
        rating-count: u0
      })
    ;; Increment project ID
    (var-set next-project-id (+ project-id u1))
    (ok project-id)
  )
)

(define-public (verify-project (project-id uint))
  (let ((caller tx-sender))
    ;; Validate project-id
    (asserts! (is-valid-project-id project-id) ERR_INVALID_PROJECT_ID)
    ;; Check if organization exists
    (asserts! (is-some (map-get? organizations {org-id: caller})) ERR_NOT_FOUND)
    ;; Check if project exists
    (asserts! (is-some (map-get? carbon-projects {project-id: project-id})) ERR_NOT_FOUND)
    
    ;; Get project data
    (let ((project (unwrap! (map-get? carbon-projects {project-id: project-id}) ERR_NOT_FOUND)))
      ;; Check if organization is not the project owner
      (asserts! (not (is-eq caller (get owner project))) ERR_SELF_RATING)
      ;; Check if organization has not already verified this project
      (asserts! (is-none (map-get? project-verifications {project-id: project-id, verifier: caller})) ERR_ALREADY_VERIFIED)
      
      ;; Record verification with validated project-id
      (map-set project-verifications 
        {project-id: project-id, verifier: caller} 
        {verified: true})
      
      ;; Update project verification count
      (let ((new-verification-count (+ (get verification-count project) u1))
            (project-owner (unwrap! (map-get? organizations {org-id: (get owner project)}) ERR_NOT_FOUND))
            (verifier-org (unwrap! (map-get? organizations {org-id: caller}) ERR_NOT_FOUND)))
        
        ;; Update project data with validated project-id
        (map-set carbon-projects 
          {project-id: project-id} 
          (merge project {
            verification-count: new-verification-count,
            verified: (>= new-verification-count u3)
          }))
        
        ;; Reward verifier with tokens
        (map-set organizations 
          {org-id: caller} 
          (merge verifier-org {
            tokens: (+ (get tokens verifier-org) u5),
            reputation: (+ (get reputation verifier-org) u1)
          }))
        
        ;; If project becomes verified (3+ verifications), reward owner
        (if (and (>= new-verification-count u3) (not (get verified project)))
          (map-set organizations 
            {org-id: (get owner project)} 
            (merge project-owner {
              tokens: (+ (get tokens project-owner) VERIFICATION_REWARD),
              reputation: (+ (get reputation project-owner) u10),
              verified: true
            }))
          true)
        
        (ok new-verification-count)
      )
    )
  )
)

(define-public (purchase-offset (project-id uint) (offset-amount uint))
  (let ((caller tx-sender))
    ;; Validate project-id
    (asserts! (is-valid-project-id project-id) ERR_INVALID_PROJECT_ID)
    ;; Validate offset amount
    (asserts! (> offset-amount u0) ERR_INVALID_INPUT)
    ;; Check if organization exists
    (asserts! (is-some (map-get? organizations {org-id: caller})) ERR_NOT_FOUND)
    ;; Check if project exists
    (asserts! (is-some (map-get? carbon-projects {project-id: project-id})) ERR_NOT_FOUND)
    
    ;; Get project data
    (let ((project (unwrap! (map-get? carbon-projects {project-id: project-id}) ERR_NOT_FOUND)))
      ;; Check if project is verified
      (asserts! (get verified project) ERR_UNAUTHORIZED)
      
      ;; Record offset with validated project-id
      (map-set carbon-offsets 
        {project-id: project-id, buyer: caller} 
        {offset-amount: offset-amount, offset-date: (var-get action-counter)})
      
      ;; Update project offset count
      (let ((new-offset-count (+ (get offset-count project) offset-amount))
            (project-owner (unwrap! (map-get? organizations {org-id: (get owner project)}) ERR_NOT_FOUND)))
        
        ;; Update project data with validated project-id
        (map-set carbon-projects 
          {project-id: project-id} 
          (merge project {offset-count: new-offset-count}))
        
        ;; Reward project owner with tokens for offset
        (map-set organizations 
          {org-id: (get owner project)} 
          (merge project-owner {
            tokens: (+ (get tokens project-owner) (* OFFSET_REWARD offset-amount))
          }))
        
        (ok new-offset-count)
      )
    )
  )
)

(define-public (rate-project-impact (project-id uint) (rating uint))
  (let ((caller tx-sender))
    ;; Validate project-id
    (asserts! (is-valid-project-id project-id) ERR_INVALID_PROJECT_ID)
    ;; Validate rating (1-5)
    (asserts! (and (>= rating u1) (<= rating MAX_RATING)) ERR_INVALID_RATING)
    ;; Check if organization exists
    (asserts! (is-some (map-get? organizations {org-id: caller})) ERR_NOT_FOUND)
    ;; Check if project exists
    (asserts! (is-some (map-get? carbon-projects {project-id: project-id})) ERR_NOT_FOUND)
    
    ;; Get project data
    (let ((project (unwrap! (map-get? carbon-projects {project-id: project-id}) ERR_NOT_FOUND)))
      ;; Check if organization is not the project owner
      (asserts! (not (is-eq caller (get owner project))) ERR_SELF_RATING)
      ;; Check if organization has not already rated this project
      (asserts! (is-none (map-get? impact-ratings {project-id: project-id, rater: caller})) ERR_ALREADY_RATED)
      
      ;; Record rating with validated project-id and rating
      (map-set impact-ratings 
        {project-id: project-id, rater: caller} 
        {rating: rating})
      
      ;; Update project rating
      (let ((current-total-rating (* (get impact-rating project) (get rating-count project)))
            (new-rating-count (+ (get rating-count project) u1))
            (new-total-rating (+ current-total-rating rating))
            (new-average-rating (/ new-total-rating new-rating-count))
            (project-owner (unwrap! (map-get? organizations {org-id: (get owner project)}) ERR_NOT_FOUND))
            (rater-org (unwrap! (map-get? organizations {org-id: caller}) ERR_NOT_FOUND)))
        
        ;; Update project data with validated project-id
        (map-set carbon-projects 
          {project-id: project-id} 
          (merge project {
            impact-rating: new-average-rating,
            rating-count: new-rating-count
          }))
        
        ;; Reward rater with tokens
        (map-set organizations 
          {org-id: caller} 
          (merge rater-org {
            tokens: (+ (get tokens rater-org) u2),
            reputation: (+ (get reputation rater-org) u1)
          }))
        
        ;; Reward project owner based on rating
        (if (>= rating u4)
          (map-set organizations 
            {org-id: (get owner project)} 
            (merge project-owner {
              tokens: (+ (get tokens project-owner) IMPACT_REWARD),
              reputation: (+ (get reputation project-owner) u5)
            }))
          true)
        
        (ok new-average-rating)
      )
    )
  )
)

;; Read-only functions
(define-read-only (get-organization-info (org-id principal))
  (map-get? organizations {org-id: org-id})
)

(define-read-only (get-project (project-id uint))
  (map-get? carbon-projects {project-id: project-id})
)

(define-read-only (get-project-verification (project-id uint) (verifier principal))
  (map-get? project-verifications {project-id: project-id, verifier: verifier})
)

(define-read-only (get-carbon-offset (project-id uint) (buyer principal))
  (map-get? carbon-offsets {project-id: project-id, buyer: buyer})
)

(define-read-only (get-impact-rating (project-id uint) (rater principal))
  (map-get? impact-ratings {project-id: project-id, rater: rater})
)

(define-read-only (get-total-projects)
  (- (var-get next-project-id) u1)
)