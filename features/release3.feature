Feature: Release management
  As a product owner
  I want to manage releases
  So that i can break down a large product backlog

  Background:
    Given the ecookbook project has the backlogs plugin enabled
      And no versions or issues exist
      And I am a product owner of the project
      And I have defined the following sprints:
        | name       | sprint_start_date | effective_date |
        | Sprint 001 | 2010-01-01        | 2010-01-31     |
        | Sprint 002 | 2010-02-01        | 2010-02-28     |
        | Sprint 003 | 2010-03-01        | 2010-03-31     |
      And I have defined the following releases:
        | name    | project    | release_start_date | release_end_date |
        | Rel 1   | ecookbook  | 2010-01-01         | 2010-02-28       |
        | Rel 2   | ecookbook  | 2010-03-01         | 2010-06-01       |
      And I have defined the following stories in the product backlog:
        | subject | release | points |
        | Story 1 | Rel 1   | 2 |
        | Story 2 | Rel 1   | 7 |
        | Story 3 | Rel 2   | 13 |
        | Story 4 | Rel 2   | 20 |
        | Story 5 |         | 40 |
      And I have defined the following stories in the following sprints:
        | subject | sprint     | release | points |
        | Story A | Sprint 001 | Rel 1   | 2 |
        | Story B | Sprint 002 | Rel 1   | 3 |
        | Story C | Sprint 003 | Rel 2   | 5 |
        | Story D | Sprint 003 |         | 5 |

  Scenario: View the release page
    Given I view the release page
     Then I should see "Release Planning" within "h2"
      And I should see "Rel 1" within "#content"
      And I should see "Rel 2" within "#content"
      And story Story 1 should belong to release Rel 1
      And story Story 2 should belong to release Rel 1
      And story Story 3 should belong to release Rel 2
      And story Story 4 should belong to release Rel 2
      And story Story A should belong to release Rel 1
      And story Story B should belong to release Rel 1
      And story Story C should belong to release Rel 2
      And story Story 5 should not belong to any release
      And release "Rel 1" should have 14 story points
      And release "Rel 2" should have 38 story points
     When I follow "Rel 1"
     Then release "Rel 1" should have 2 sprints
     Then I should see "Sprints" within "#content"
      And I should see "Sprint 001" within "#sprints"
      And I should see "Sprint 002" within "#sprints"
      # Disabled temporarily: And I should see "Release Burndown" within "#content"

  Scenario: Create a new release
    Given I view the release page
     Then I should see "Release Planning"
     When I follow "New release"
     Then I should see "New release" within "h2"
     When I fill in the following:
       | release_name | A totally new release |
       | release_release_start_date | 2010-04-01 |
       | release_release_end_date | 2010-04-30 |
     When I press "Create"
     Then I should see "Successful creation"

  Scenario: Delete a release
    Given I view the release page
     Then I should see "Release Planning"
     When I follow "Rel 1"
     Then I should see "Delete" within ".contextual"
     When I follow "Delete" within ".contextual"
     Then I should see "Release Planning"
     Then I should not see "Rel 1"

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

  Scenario: Add a story to a release
    Given I am viewing the master backlog
     When I add story Story 5 to release Rel 1
     Then story Story 5 should belong to release Rel 1
      And release "Rel 1" should have 54 story points
      And journal for "Story 5" should show change to release "Rel 1"

  Scenario: Close a release
    Given I view the release page
     Then I should see "Release Planning"
     When I follow "Rel 1"
     Then I should see "Edit" within ".contextual"
     When I follow "Edit" within ".contextual"
     Then I should see "Release" within "#content"
     When I select "closed" from "release_status"
      And I press "Save"
     Then I should see "Successful update"
      And The release "Rel 1" should be closed

  Scenario: view master backlog page with releases
    Given I am viewing the master backlog
     Then I should see the product backlog
      And I should see 1 stories in the product backlog
      And I should see the release backlog of Rel 1
      And I should see 2 stories in the release backlog of Rel 1
      And I should see the release backlog of Rel 2
      And I should see 2 stories in the release backlog of Rel 2
      And I should see 3 sprint backlogs
      And I should see 1 stories in the sprint backlog of Sprint 001
      And I should see 1 stories in the sprint backlog of Sprint 002
      And I should see 2 stories in the sprint backlog of Sprint 003

  Scenario: View issues grouped by releases
    Given I view issues tab grouped by releases
     Then I should see "Rel 1" group in the issues list
     Then I should see "Rel 2" group in the issues list

  @javascript
  Scenario: Go to a release backlog query using the issues sidebar
    Given I am viewing the issues list
     Then I should see "Rel 1" within "#sidebar"
     When I follow "Rel 1"
      And I should see "Issues" within "#content"
      And I should see "Story A" within "#content"
      And I should see "Story B" within "#content"
      And I should not see "Story C" within "#content"

  Scenario: Bulk edit issue's release attributes
    Given I am viewing the issues list
      And I want to bulk edit "Story A" and "Story B"
      And I want to set the release to "Rel 2"
      And I want to set the release relationship to Initial
     When I update the stories
      Then story "Story A" should have release "Rel 2"
      Then story "Story B" should have release "Rel 2"
      Then story "Story A" should have release relationship Initial
      Then story "Story B" should have release relationship Initial

# FIXME Scenario: Bulk edit release attributes across projects
# FIXME Scenario: Shared releases
