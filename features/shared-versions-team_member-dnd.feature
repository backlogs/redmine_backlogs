Feature: Team Member
  As a team member
  I want to drag tasks on a sprint shared across projects
  So that I can update everyone on the status of the sprint

  Background:
    Given the ecookbook project has the backlogs plugin enabled
      And the subproject1 project has the backlogs plugin enabled
      And sharing is enabled
      And I have selected the ecookbook project
      And no versions or issues exist
      And I am a team member of the project
      And I have deleted all existing issues
      And I have defined the following sprints:
        | name       | sprint_start_date | effective_date | project_id   | sharing     |
        | Sprint 001 | 2010-01-01        | 2010-01-31     | ecookbook    | descendants |
        | Sprint 002 | 2010-02-01        | 2010-02-28     | ecookbook    | descendants |
      And I have defined the following stories in the following sprints:
        | subject | sprint     | project_id   |
        | Story 1 | Sprint 001 | ecookbook    |
        | Story 2 | Sprint 001 | ecookbook    |
        | Story 3 | Sprint 001 | subproject1  |
        | Story 4 | Sprint 002 | ecookbook    |
      And I have defined the following tasks:
        | subject | story  |
        | Task 1  | Story 1 |
        | Task 2  | Story 2 |
        | Task 3  | Story 3 |
      And I have defined the following impediments:
        | subject      | sprint     | blocks  |
        | Impediment 1 | Sprint 001 | Story 1 |
        | Impediment 3 | Sprint 001 | Story 3 | 
        
  @javascript
  Scenario: View a taskboard
    Given I am viewing the taskboard for Sprint 001
     Then I should see the taskboard
      And I should see task Task 1 in the row of story Story 1 in the state New 
      And I should see task Task 2 in the row of story Story 2 in the state New 
      And I should see task Task 3 in the row of story Story 3 in the state New 
      And I should see impediment Impediment 1 in the state New 
      And I should see impediment Impediment 3 in the state New 

  @javascript @optional
  Scenario: Drag a task to a new state in the same story
    Given I am viewing the taskboard for Sprint 001
     Then I should see the taskboard
     When I drag task Task 1 to the state Assigned in the row of Story 1
     Then I should see task Task 1 in the row of story Story 1 in the state Assigned
      And task Task 1 should have the status Assigned

  @javascript
  Scenario: Drag a task of a subproject to a new state in the same story
    Given I am viewing the taskboard for Sprint 001
     Then I should see the taskboard
     When I drag task Task 3 to the state Assigned in the row of Story 3
     Then I should see task Task 3 in the row of story Story 3 in the state Assigned
      And task Task 3 should have the status Assigned

  @javascript
  Scenario: Drag a task to a new state in another story
    Given I am viewing the taskboard for Sprint 001
     Then I should see the taskboard
     When I drag task Task 1 to the state Assigned in the row of Story 2
     Then I should see task Task 1 in the row of story Story 2 in the state Assigned
      And task Task 1 should have the status Assigned
     #negative test: drag into a disabled area (other project)
     When I drag task Task 1 to the state New in the row of Story 3
     Then I should see task Task 1 in the row of story Story 2 in the state Assigned
      And task Task 1 should have the status Assigned
