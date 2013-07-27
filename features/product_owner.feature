Feature: Product Owner
  As a product owner
  I want to manage story details and story priority
  So that they get done according to my requirements

  Background:
    Given the ecookbook project has the backlogs plugin enabled
      And no versions or issues exist
      And I am a product owner of the project
      And I add the tracker Bug to the story trackers
      And I have defined the following sprints:
        | name       | sprint_start_date | effective_date |
        | Sprint 001 | 2010-01-01        | 2010-01-31     |
        | Sprint 002 | 2010-02-01        | 2010-02-28     |
        | Sprint 003 | 2010-03-01        | 2010-03-31     |
        | Sprint 004 | 2010-03-01        | 2010-03-31     |
      And I have deleted all existing issues
      And I have defined the following stories in the product backlog:
        | subject | tracker |
        | Story 1 | Story   |
        | Story 2 | Story   |
        | Story 3 | Story   |
        | Story 4 | Story   |
        | Bug 1   | Bug     |
      And I have defined the following stories in the following sprints:
        | subject | sprint     |
        | Story A | Sprint 001 |
        | Story B | Sprint 001 |

  Scenario: View the product backlog
    Given I am viewing the master backlog
     Then I should see the product backlog
      And I should see 5 stories in the product backlog
      And I should see 4 sprint backlogs

  Scenario: View scrum statistics
     When I visit the scrum statistics page
     Then the request should complete successfully

  Scenario: Create a new story
    Given I am viewing the master backlog
      And I want to create a story
      And I set the subject of the story to A Whole New Story
     When I create the story
     Then the request should complete successfully
      And the 1st story in the product backlog should be A Whole New Story

  @javascript
  Scenario: Create a new story with tracker Story to check default story tracker functionality
    Given I add the tracker Bug to the story trackers
      And I set the default story tracker to Story
      And I am viewing the master backlog
     When I create the story with subject "A default Story"
     Then the request should complete successfully
      And the 1th story in the product backlog should be A default Story
      And the 1th story in the product backlog should have the tracker Story

  @javascript
  Scenario: Create a new story with tracker Bug to check default story tracker functionality
    Given I add the tracker Bug to the story trackers
      And I set the default story tracker to Bug
      And I am viewing the master backlog
     When I create the story with subject "A default Bug"
     Then the request should complete successfully
      And the 1st story in the product backlog should be A default Bug
      And the 1st story in the product backlog should have the tracker Bug

  @javascript
  Scenario: Edit an existing default story with full javascript stack to check default tracker does not override when editing.
    Given I add the tracker Bug to the story trackers
      And I set the default story tracker to Bug
      And I am viewing the master backlog
      And I want to edit the story with subject Story 1
     When I change the subject of story "Story 1" to "A modified default Story"
     Then the request should complete successfully
      And the story should have a subject of A modified default Story
      And the story should have a tracker of Story
      
  Scenario: Update a story
    Given I am viewing the master backlog
      And I want to edit the story with subject Story 3
      And I set the subject of the story to Relaxdiego was here
      And I set the tracker of the story to Story
     When I update the story
     Then the request should complete successfully
      And the story should have a subject of Relaxdiego was here
      And the story should have a tracker of Story
      And the story should be at position 3

  Scenario: Close a story
    Given I am viewing the master backlog
      And I want to edit the story with subject Story 4
      And I set the status of the story to Closed
     When I update the story
     Then the request should complete successfully
      And the status of the story should be set as closed

  Scenario: Move a story to the top
    Given I am viewing the master backlog
     When I move the 3rd story to the 1st position
     Then the 1st story in the product backlog should be Story 3

  Scenario: Move a story to the bottom
    Given I am viewing the master backlog
     When I move the 2nd story to the last position
     Then the 5th story in the product backlog should be Story 2

  Scenario: Move a story down
    Given I am viewing the master backlog
     When I move the 2nd story to the 3rd position
     Then the 2nd story in the product backlog should be Story 3
      And the 3rd story in the product backlog should be Story 2
      And the 4th story in the product backlog should be Story 4

  Scenario: Move a story up
    Given I am viewing the master backlog
     When I move the 4th story to the 2nd position
     Then the 2nd story in the product backlog should be Story 4
      And the 3rd story in the product backlog should be Story 2
      And the 4th story in the product backlog should be Story 3

  Scenario: Move many stories up so the gapspace needs reassignment
    Given I am viewing the master backlog
     When I move the 4th story to the 2nd position
    Given I am viewing the master backlog
     When I move the 4th story to the 2nd position
    Given I am viewing the master backlog
     When I move the 4th story to the 2nd position
    Given I am viewing the master backlog
     When I move the 4th story to the 2nd position
    Given I am viewing the master backlog
     When I move the 4th story to the 2nd position
    Given I am viewing the master backlog
     When I move the 4th story to the 2nd position
    Given I am viewing the master backlog
     When I move the 4th story to the 2nd position
    Given I am viewing the master backlog
     When I move the 4th story to the 2nd position
    Given I am viewing the master backlog
     When I move the 4th story to the 2nd position
    Given I am viewing the master backlog
     When I move the 4th story to the 2nd position
    Given I am viewing the master backlog
     When I move the 4th story to the 2nd position
    Given I am viewing the master backlog
     When I move the 4th story to the 2nd position
    Given I am viewing the master backlog
     When I move the 4th story to the 2nd position
    Given I am viewing the master backlog
     Then the 2nd story in the product backlog should be Story 4
      And the 3rd story in the product backlog should be Story 2
      And the 4th story in the product backlog should be Story 3

