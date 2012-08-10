Feature: Chief Product Owner story ordering
  As a product owner
  I want to delegate story management to sub project owners
  So that they can priorize the subproject but have minimal impact on the overall ordering

  Background:
    Given the ecookbook project has the backlogs plugin enabled
      And the subproject1 project has the backlogs plugin enabled
      And sharing is enabled
      And I have selected the ecookbook project
      And no versions or issues exist
      And I am a product owner of the project
      And I have defined the following stories in the product backlog:
        | subject | project_id  |
        | Story 1 | ecookbook   |
        | Story 2 | ecookbook   |
        | Story 6 | subproject1 |
        | Story 7 | subproject1 |
        | Story 3 | ecookbook   |
        | Story 4 | ecookbook   |
        | Story 5 | ecookbook   |
        | Story 8 | subproject1 |
        | Story 9 | subproject1 |
      And I have defined the following sprints:
        | name       | sprint_start_date | effective_date | sharing     | project_id    |
        | Sp001      | 2010-01-01        | 2010-01-31     | descendants | ecookbook     |
      And I have defined the following stories in the following sprints:
        | subject | sprint     | project_id    |
        | Story A | Sp001      | ecookbook     |
        | Story B | Sp001      | subproject1   |

  @optional
  Scenario: View the toplevel product backlog
    Given I am viewing the master backlog
     Then I should see the product backlog
      And I should see 9 stories in the product backlog
      And I should see 1 sprint backlogs
      And the 1st story in the product backlog should be Story 1
      And the 2nd story in the product backlog should be Story 2
      And the 3rd story in the product backlog should be Story 6
      And the 4th story in the product backlog should be Story 7
      And the 5th story in the product backlog should be Story 3
      And the 6th story in the product backlog should be Story 4
      And the 7th story in the product backlog should be Story 5
      And the 8th story in the product backlog should be Story 8
      And the 9th story in the product backlog should be Story 9

  @optional
  Scenario: View the sub product backlog
    Given I have selected the subproject1 project
      And I am viewing the master backlog
     Then I should see the product backlog
      And I should see 4 stories in the product backlog
      And I should see 1 sprint backlogs
      And the 1st story in the product backlog should be Story 6
      And the 2nd story in the product backlog should be Story 7
      And the 3rd story in the product backlog should be Story 8
      And the 4th story in the product backlog should be Story 9

  Scenario: Move story 7 in subproject to 3rd pos and expect 7 to be before 9 and after 8
    Given I have selected the subproject1 project
      And I am viewing the master backlog
     Then I should see the product backlog
     When I move the 2nd story to the 3rd position
     Then the 1st story in the product backlog should be Story 6
      And the 2nd story in the product backlog should be Story 8
      And the 3rd story in the product backlog should be Story 7
      And the 4th story in the product backlog should be Story 9
    Given I have selected the ecookbook project
      And I am viewing the master backlog
     Then I should see the product backlog
      And the 1st story in the product backlog should be Story 1
      And the 2nd story in the product backlog should be Story 2
      And the 3rd story in the product backlog should be Story 6
      And the 4th story in the product backlog should be Story 3
      And the 5th story in the product backlog should be Story 4
      And the 6th story in the product backlog should be Story 5
      And the 7th story in the product backlog should be Story 8
      And the 8th story in the product backlog should be Story 7
      And the 9th story in the product backlog should be Story 9

  @optional
  Scenario: Move story 6 in subproject to 2nd pos and expect 6 to be after 5 and before 8
    Given I have selected the subproject1 project
      And I am viewing the master backlog
     Then I should see the product backlog
     When I move the 1st story to the 2nd position
     Then the 1st story in the product backlog should be Story 7
      And the 2nd story in the product backlog should be Story 6
      And the 3rd story in the product backlog should be Story 8
      And the 4th story in the product backlog should be Story 9
    Given I have selected the ecookbook project
      And I am viewing the master backlog
     Then I should see the product backlog
      And the 1st story in the product backlog should be Story 1
      And the 2nd story in the product backlog should be Story 2
      And the 3rd story in the product backlog should be Story 7
      And the 4th story in the product backlog should be Story 3
      And the 5th story in the product backlog should be Story 4
      And the 6th story in the product backlog should be Story 5
      And the 7th story in the product backlog should be Story 6
      And the 8th story in the product backlog should be Story 8
      And the 9th story in the product backlog should be Story 9

  Scenario: Move story 7 in subproject to the top and expect 7 to be after 2 and before 6
    Given I have selected the subproject1 project
      And I am viewing the master backlog
     Then I should see the product backlog
     When I move the 2nd story to the 1st position
     Then the 1st story in the product backlog should be Story 7
      And the 2nd story in the product backlog should be Story 6
      And the 3rd story in the product backlog should be Story 8
      And the 4th story in the product backlog should be Story 9
    Given I have selected the ecookbook project
      And I am viewing the master backlog
     Then I should see the product backlog
      And the 1st story in the product backlog should be Story 1
      And the 2nd story in the product backlog should be Story 2
      And the 3rd story in the product backlog should be Story 7
      And the 4th story in the product backlog should be Story 6
      And the 5th story in the product backlog should be Story 3
      And the 6th story in the product backlog should be Story 4
      And the 7th story in the product backlog should be Story 5
      And the 8th story in the product backlog should be Story 8
      And the 9th story in the product backlog should be Story 9

  @optional
  Scenario: Move story 8 in subproject to 2nd pos and expect 8 to be after 6 and before 7
    Given I have selected the subproject1 project
      And I am viewing the master backlog
     Then I should see the product backlog
     When I move the 3rd story to the 2nd position
     Then the 1st story in the product backlog should be Story 6
      And the 2nd story in the product backlog should be Story 8
      And the 3rd story in the product backlog should be Story 7
      And the 4th story in the product backlog should be Story 9
    Given I have selected the ecookbook project
      And I am viewing the master backlog
     Then I should see the product backlog
      And the 1st story in the product backlog should be Story 1
      And the 2nd story in the product backlog should be Story 2
      And the 3rd story in the product backlog should be Story 6
      And the 4th story in the product backlog should be Story 8
      And the 5th story in the product backlog should be Story 7
      And the 6th story in the product backlog should be Story 3
      And the 7th story in the product backlog should be Story 4
      And the 8th story in the product backlog should be Story 5
      And the 9th story in the product backlog should be Story 9

  @optional
  Scenario: Move story 9 in subproject to 3rd pos and expect 9 to be after 5 and before 8
    Given I have selected the subproject1 project
      And I am viewing the master backlog
     Then I should see the product backlog
     When I move the 4th story to the 3rd position
     Then the 1st story in the product backlog should be Story 6
      And the 2nd story in the product backlog should be Story 7
      And the 3rd story in the product backlog should be Story 9
      And the 4th story in the product backlog should be Story 8
    Given I have selected the ecookbook project
      And I am viewing the master backlog
     Then I should see the product backlog
      And the 1st story in the product backlog should be Story 1
      And the 2nd story in the product backlog should be Story 2
      And the 3rd story in the product backlog should be Story 6
      And the 4th story in the product backlog should be Story 7
      And the 5th story in the product backlog should be Story 3
      And the 6th story in the product backlog should be Story 4
      And the 7th story in the product backlog should be Story 5
      And the 8th story in the product backlog should be Story 9
      And the 9th story in the product backlog should be Story 8

  @optional
  Scenario: Move story 7 in subproject to the bottom and expect 7 to be after 9
    Given I have selected the subproject1 project
      And I am viewing the master backlog
     Then I should see the product backlog
     When I move the 2nd story to the 4th position
     Then the 1st story in the product backlog should be Story 6
      And the 2nd story in the product backlog should be Story 8
      And the 3rd story in the product backlog should be Story 9
      And the 4th story in the product backlog should be Story 7
    Given I have selected the ecookbook project
      And I am viewing the master backlog
     Then I should see the product backlog
      And the 1st story in the product backlog should be Story 1
      And the 2nd story in the product backlog should be Story 2
      And the 3rd story in the product backlog should be Story 6
      And the 4th story in the product backlog should be Story 3
      And the 5th story in the product backlog should be Story 4
      And the 6th story in the product backlog should be Story 5
      And the 7th story in the product backlog should be Story 8
      And the 8th story in the product backlog should be Story 9
      And the 9th story in the product backlog should be Story 7

#  Scenario: Create new story in subproject and expect it to be before the first of subproject but after all others which where before already
#  Scenario: Move a story from a sprint back to the subproject backlog  at the top
#  Scenario: Move a story from a sprint back to the subproject backlog  at the 2nd position
#  Scenario: Move a story from a sprint back to the subproject backlog  at the 3rd position
#  Scenario: Move a story from a sprint back to the subproject backlog  at the bottom
#  Scenario: Create a new story in subproject when new stories default to top and expect it before 6 and after 2
#  Scenario: Create a new story in subproject when new stories default to bottom and expect after 9
