Feature: Scrum Master
  As a scrum master
  I want to manage sprints and their stories
  So that they get done according the product owner's requirements

  Background:
    Given the ecookbook project has the backlogs plugin enabled
      And the subproject1 project has the backlogs plugin enabled

      And I am a scrum master of the project
      And I have deleted all existing issues
      And I have defined the following sprints:
        | name       | sprint_start_date | effective_date  | project_id  |
        | Sprint 001 | 2010-01-01        | 2010-01-31      | ecookbook   |
        | Sprint 002 | 2010-02-01        | 2010-02-28      | ecookbook   |
        | Sprint 003 | 2010-03-01        | 2010-03-31      | ecookbook   |
        | Sprint 004 | 2 weeks ago       | next week       | ecookbook   |
        | Sprint S05 | 2010-01-01        | 2010-01-31      | subproject1 |

  Scenario: Interlieve story creation in backlog between projects
    Given I have defined the following stories in the product backlog:
        | subject | project_id  |
        | Story 1 | ecookbook   |
        | Story 2 | ecookbook   |
        | Story 6 | subproject1 |
        | Story 7 | subproject1 |
        | Story 3 | ecookbook   |
        | Story 4 | ecookbook   |
        | Story 8 | subproject1 |
        | Story 9 | subproject1 |
     #Then show me the higher_item attributes
     Then Story 1 should be the higher item of Story 2
     Then Story 2 should be the higher item of Story 3
     Then Story 3 should be the higher item of Story 4
     Then Story 6 should be the higher item of Story 7
     Then Story 7 should be the higher item of Story 8
     Then Story 8 should be the higher item of Story 9

  Scenario: Interlieve story creation in sprints between projects
    Given I have defined the following stories in the following sprints:
        | subject | sprint     |
        | Story C | Sprint 003 |
        | Story D | Sprint S05 |
        | Story E | Sprint 003 |
        | Story F | Sprint S05 |
    Given I am viewing the master backlog
     Then Story C should be the higher item of Story E
     Then Story D should be the higher item of Story F

  Scenario: Interlieve story creation between sprints
    Given I have defined the following stories in the product backlog:
        | subject | project_id  |
        | Story 1 | ecookbook   |
        | Story 2 | ecookbook   |
        | Story 3 | ecookbook   |
        | Story 4 | ecookbook   |
    Given I have defined the following stories in the following sprints:
        | subject | sprint     |
        | Story C | Sprint 003 |
        | Story D | Sprint 004 |
        | Story E | Sprint 003 |
        | Story F | Sprint 004 |
    Given I am viewing the master backlog
     Then Story C should be the higher item of Story E
     Then Story D should be the higher item of Story F

     When I move the story named Story 2 to the 1st position of the sprint named Sprint 002
     When I move the story named Story 4 to the 1st position of the sprint named Sprint 002
      And Story 4 should be the higher item of Story 2
      And Story 1 should be the higher item of Story 3

  Scenario: Move a story so that scoped next item in position is from another scope
    Given I have defined the following stories in the product backlog:
        | subject | project_id  |
        | Story 1 | ecookbook   |
    Given I have defined the following stories in the following sprints:
        | subject | sprint     |
        | Story C | Sprint 003 |
        | Story D | Sprint 004 |
     When I move the story named Story 1 to the 2nd position of the sprint named Sprint 003
     Then Story C should be the higher item of Story 1

  Scenario: Lowlevel higher_item and lower_item api test; should be an rspec test
    Given I have deleted all existing issues from all projects
      And I have defined the following stories in the product backlog:
        | subject | project_id  |
        | Story 1 | ecookbook   |
        | Story 2 | ecookbook   |
        | Story 6 | subproject1 |
        | Story 7 | subproject1 |
        | Story 3 | ecookbook   |
        | Story 4 | ecookbook   |
        | Story 8 | subproject1 |
        | Story 9 | subproject1 |
     #move after
     When I call move_after("Story 7") on "Story 1"
     Then "Story 1".higher_item_unscoped should be "Story 7"
     Then "Story 1".lower_item_unscoped should be "Story 3"
     #move after to the end
     When I call move_after("Story 9") on "Story 1"
     Then "Story 1".higher_item_unscoped should be "Story 9"
     Then "Story 1".lower_item_unscoped should be "nil"
     #move before
     When I call move_before("Story 7") on "Story 1"
     Then "Story 1".higher_item_unscoped should be "Story 6"
     Then "Story 1".lower_item_unscoped should be "Story 7"
     #move before to the beginning
     When I call move_before("Story 2") on "Story 1"
     Then "Story 1".lower_item_unscoped should be "Story 2"
     Then "Story 1".higher_item_unscoped should be "nil"
