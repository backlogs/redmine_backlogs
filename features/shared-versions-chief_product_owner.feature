Feature: Shared versions multiple subprojects, one sprint
  As a chief project manager 
  I want to manage two backlogs but one team
  So that both projects get priorized and done according to my decisions

  Background:
    Given the ecookbook project has the backlogs plugin enabled
      And sharing is enabled
      And I have defined the following projects:
        | name   |
        | p1     |
        | p1s1   |
        | p1s2   |

      And the p1 project has the backlogs plugin enabled
      And the p1s1 project has the backlogs plugin enabled
      And the p1s1 project is subproject of the p1 project
      And the p1s2 project has the backlogs plugin enabled
      And the p1s2 project is subproject of the p1 project
      And no versions or issues exist
      And I am a product owner of the project
      And I have defined the following sprints:
        | name       | sprint_start_date | effective_date | sharing     | project_id    |
        | Sp001      | 2010-01-01        | 2010-01-31     | descendants | p1            |

      And I have defined the following stories in the product backlog:
        | subject | project_id    |
        | Story 1 | ecookbook     |
        | Story 2 | p1            |
        | Story 3 | p1s1          |
        | Story 4 | p1s1          |
        | Story 5 | p1s2          |
        | Story 6 | p1s2          |

  @javascript
  Scenario: Plan a sprint in the parent project from two subprojects backlogs, which do not share any version
    Given I have selected the p1 project
      And I am viewing the master backlog
     Then I should see the product backlog
      And I should see 5 stories in the product backlog
      And I should see 1 sprint backlogs
      And I should see the backlog of Sprint Sp001
      And I should see 0 stories in the sprint backlog of Sp001
      And The menu of the product backlog should allow to create a new Story in project p1
      And The menu of the product backlog should allow to create a new Story in project p1s1
      And The menu of the product backlog should allow to create a new Story in project p1s2
      And The menu of the sprint backlog of Sp001 should allow to create a new Story in project p1
      And The menu of the sprint backlog of Sp001 should allow to create a new Story in project p1s1
      And The menu of the sprint backlog of Sp001 should allow to create a new Story in project p1s2
#     When I drag story Story 3 to the sprint backlog of Sp001
#     Then Story 3 should be in the 1st position of the sprint named Sp001
#     When I drag story Story 4 to the sprint backlog of Sp001
#     Then Story 4 should be in the 2nd position of the sprint named Sp001
#     When I drag story Story 5 to the sprint backlog of Sp001
#     Then Story 5 should be in the 3rd position of the sprint named Sp001
#     When I drag story Story 6 to the sprint backlog of Sp001 before the story Story 4
#     Then Story 6 should be in the 2nd position of the sprint named Sp001
#      And I should see 4 stories in the sprint backlog of Sp001
