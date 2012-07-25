@optional
Feature: Shared versions one backlog multiple subproject team sprints
  As a chief project manager 
  I want to manage one backlogs but two teams
  So that both teams work in their own sprint

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
        | Sp001      | 2010-01-01        | 2010-01-31     | hierarchy   | p1s1          |
        | Sp002      | 2010-01-01        | 2010-01-31     | hierarchy   | p1s2          |

      And I have defined the following stories in the product backlog:
        | subject | project_id    |
        | Story 1 | ecookbook     |
        | Story 2 | p1            |
        | Story 3 | p1            |
        | Story 4 | p1            |
        | Story 5 | p1            |
        | Story 6 | p1            |

  @javascript
  Scenario: Plan 2 sprints of subprojects from the parent projects backlog
    Given I have selected the p1 project
      And I am viewing the master backlog
     Then I should see the product backlog
      And I should see 5 stories in the product backlog
      And I should see 2 sprint backlogs
      And I should see the backlog of Sprint Sp001
      And I should see the backlog of Sprint Sp002
      And I should see 0 stories in the sprint backlog of Sp001
      And I should see 0 stories in the sprint backlog of Sp002
      And The menu of the product backlog should allow to create a new Story in project p1
      And The menu of the product backlog should allow to create a new Story in project p1s1
      And The menu of the product backlog should allow to create a new Story in project p1s2
      And The menu of the sprint backlog of Sp001 should allow to create a new Story in project p1
      And The menu of the sprint backlog of Sp001 should allow to create a new Story in project p1s1
      And The menu of the sprint backlog of Sp002 should allow to create a new Story in project p1
      And The menu of the sprint backlog of Sp002 should allow to create a new Story in project p1s2
      And The menu of the sprint backlog of Sp001 should not allow to create a new Story in project p1s2
      And The menu of the sprint backlog of Sp002 should not allow to create a new Story in project p1s1
#     When I drag story Story 2 to the sprint backlog of Sp001
#     Then Story 2 should be in the 1st position of the sprint named Sp001
#     When I drag story Story 3 to the sprint backlog of Sp001
#     Then Story 3 should be in the 2nd position of the sprint named Sp001
#     When I drag story Story 4 to the sprint backlog of Sp002
#     Then Story 4 should be in the 1st position of the sprint named Sp002
#     When I drag story Story 5 to the sprint backlog of Sp002
#     Then Story 5 should be in the 2nd position of the sprint named Sp002
#     When I drag story Story 6 to the sprint backlog of Sp001 before the story Story 3
#     Then Story 6 should be in the 2nd position of the sprint named Sp001
#      And I should see 3 stories in the sprint backlog of Sp001
#      And I should see 2 stories in the sprint backlog of Sp002
