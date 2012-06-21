Feature: Product Owner
  As a product owner
  I want to manage releases
  So that i can track a large product backlog

  Background:
    Given the ecookbook project has the backlogs plugin enabled
      And I am a product owner of the project
      And I have defined the following sprints:
        | name       | sprint_start_date | effective_date |
        | Sprint 001 | 2010-01-01        | 2010-01-31     |
        | Sprint 002 | 2010-02-01        | 2010-02-28     |
        | Sprint 003 | 2010-03-01        | 2010-03-31     |
      And I have defined the following stories in the product backlog:
        | subject |
        | Story 1 |
        | Story 2 |
        | Story 3 |
        | Story 4 |
      And I have defined the following stories in the following sprints:
        | subject | sprint     |
        | Story A | Sprint 001 |
        | Story B | Sprint 002 |
      And I have defined the following releases:
        | name    | project    | release_start_date | release_end_date | initial_story_points |
        | Rel 1   | ecookbook  | 2010-01-01         | 2010-02-28       | 0 |
        | Rel 2   | ecookbook  | 2010-03-01         | 2010-06-01       | 0 |
  Scenario: View the release page
    Given I view the release page
     Then I should see "Release Planning" within "h2"
      And I should see "Rel 1" within "#content"
      And I should see "Rel 2" within "#content"
    When I follow "Rel 1"
     Then I should see "Sprints" within "#content"
     Then I should see "Sprint 001" within "#sprints"
     And I should see "Sprint 002" within "#sprints"
     And I should see "Release Burndown" within "#content"
     And I should see "Saved point snapshots:" within "#sidebar"

  Scenario: Create a new release
    Given I view the release page
     Then I should see "Release Planning"
     When I follow "New release"
     Then I should see "New release" within "h2"
     When I fill in the following:
       | release_name | A totally new release |
       | release_release_start_date | 2010-04-01 |
       | release_release_end_date | 2010-04-30 |
       | release_initial_story_points | 20 |
     When I press "Create"
     Then I should see "Successful creation"

  @javascript
  Scenario: Delete a release
    Given I view the release page
     Then I should see "Release Planning"
     When I follow "Rel 1"
     Then I should see "Delete" within ".contextual"
     When I follow "Delete" within ".contextual"
     Then I should see "Release Planning"
     Then I should not see "Rel 1"

  @javascript
  Scenario: Edit a release
    Given I view the release page
     Then I should see "Release Planning"
     When I follow "Rel 1"
     Then I should see "Edit" within ".contextual"
     When I follow "Edit" within ".contextual"
     Then I should see "Release" within "#content"
     When I fill in "release_name" with "A changed release"
      And I press "Save"
     Then I should see "Successful update"
      And I should see "A changed release" within "#content"
